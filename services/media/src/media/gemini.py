"""Google Gemini as the avatar image method (D-64, dev first): the
AvatarStylizer (gemini-2.5-flash-image edits the selfie or the portrait),
the ImageInspector (the safety check's facts) and the FaceLocator (where the
face is, for the frames), all through the Gemini API.

Only with a paid-tier key: on the free tier Google may use what is sent to
improve its products, and a person's selfie must never be used that way.
The key comes from a file (MEDIA_GEMINI_API_KEY_FILE), never the repo, and is
never logged. Photos go only to generativelanguage.googleapis.com, which must
be in MEDIA_APPROVED_HOSTS like any other image endpoint.
"""

from __future__ import annotations

import base64
import io
import json
import logging
from dataclasses import dataclass, field
from typing import Any

import httpx
from PIL import Image

from .frames import FaceBox
from .safety import ImageFacts
from .stylizer import Generated, StylizerError, check_endpoint

log = logging.getLogger("media.gemini")

ENDPOINT = "https://generativelanguage.googleapis.com"
IMAGE_MODEL = "gemini-2.5-flash-image"
VISION_MODEL = "gemini-2.5-flash"
#: Per generated image (1,290 output tokens at $30 per million).
USD_PER_IMAGE = 0.039


class GeminiError(StylizerError):
    """Gemini refused, timed out or returned nothing usable."""


def _mime(data: bytes) -> str:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG"):
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    raise GeminiError("Input is not a JPEG, PNG or WebP image")


def _part(data: bytes) -> dict[str, Any]:
    return {"inline_data": {"mime_type": _mime(data), "data": base64.b64encode(data).decode()}}


def _png(image: Image.Image, longest: int = 768) -> bytes:
    """A smaller copy for the vision model (faster, cheaper, same answer)."""
    copy = image.convert("RGBA")
    copy.thumbnail((longest, longest), Image.Resampling.LANCZOS)
    out = io.BytesIO()
    copy.save(out, "PNG")
    return out.getvalue()


@dataclass
class GeminiClient:
    """One HTTPS client for the Gemini API, checked against the approved
    hosts before anything is sent."""

    api_key: str = field(repr=False)
    approved_hosts: frozenset[str]
    endpoint: str = ENDPOINT
    timeout_s: float = 120
    transport: httpx.BaseTransport | None = None

    def call(self, model: str, body: dict[str, Any]) -> dict[str, Any]:
        check_endpoint(self.endpoint, self.approved_hosts)
        try:
            with httpx.Client(
                base_url=self.endpoint, timeout=self.timeout_s, transport=self.transport
            ) as http:
                r = http.post(
                    f"/v1beta/models/{model}:generateContent",
                    json=body,
                    headers={"x-goog-api-key": self.api_key},
                )
        except httpx.HTTPError:
            raise GeminiError("Gemini could not be reached") from None
        if r.status_code != 200:
            # The status only: the body can echo the request.
            raise GeminiError(f"Gemini refused the request ({r.status_code})")
        data: dict[str, Any] = r.json()
        return data

    @staticmethod
    def parts(response: dict[str, Any]) -> list[dict[str, Any]]:
        candidates = response.get("candidates") or []
        if not candidates:
            reason = (response.get("promptFeedback") or {}).get("blockReason", "none")
            raise GeminiError(f"Gemini gave no answer (blocked: {reason})")
        parts: list[dict[str, Any]] = (candidates[0].get("content") or {}).get("parts") or []
        return parts

    def json_answer(self, body: dict[str, Any]) -> dict[str, Any]:
        for part in self.parts(self.call(VISION_MODEL, body)):
            if "text" in part:
                try:
                    answer: dict[str, Any] = json.loads(part["text"])
                except ValueError:
                    break
                return answer
        raise GeminiError("Gemini gave no JSON answer")


@dataclass
class GeminiStylizer:
    """An AvatarStylizer: one gemini-2.5-flash-image edit per call."""

    client: GeminiClient
    model: str = IMAGE_MODEL
    endpoint: str = field(init=False)

    def __post_init__(self) -> None:
        self.endpoint = self.client.endpoint

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None) -> Generated:
        # Gemini has no negative prompt: the things to avoid go in the text.
        text = f"{prompt}\n\nDo not include: {avoid}" if avoid else prompt
        parts: list[dict[str, Any]] = [{"text": text}]
        if reference is not None:
            parts.append(_part(reference))
        response = self.client.call(
            self.model,
            {
                "contents": [{"role": "user", "parts": parts}],
                "generationConfig": {
                    "responseModalities": ["IMAGE"],
                    "imageConfig": {"aspectRatio": "1:1"},
                },
            },
        )
        for part in self.client.parts(response):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return Generated(
                    image=base64.b64decode(inline["data"]),
                    cost_usd=USD_PER_IMAGE,
                    model=self.model,
                )
        raise GeminiError("Gemini made no image")


_FACTS_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "face_count": {"type": "INTEGER"},
        "looks_under_18": {"type": "BOOLEAN"},
        "nudity": {"type": "BOOLEAN"},
        "violence": {"type": "BOOLEAN"},
        "text_or_logo": {"type": "BOOLEAN"},
        "similarity": {"type": "NUMBER"},
    },
    "required": [
        "face_count",
        "looks_under_18",
        "nudity",
        "violence",
        "text_or_logo",
        "similarity",
    ],
}

_INSPECT = (
    "You check a generated 3D-style portrait for a health app. Image 1 is the "
    "portrait. Report: face_count (human faces in image 1); looks_under_18 "
    "(true if the person in image 1 could look younger than 18); nudity; "
    "violence; text_or_logo (any readable text, letters, numbers, watermark "
    "or brand logo in image 1)."
)
_SIMILARITY = (
    " Image 2 is the real photo of the person. similarity: from 0 to 1, how "
    "clearly image 1 is a stylised likeness of the same person as image 2 "
    "(face shape, skin tone, hair, features; ignore the 3D style). 0.9 = clearly "
    "the same person, 0.3 = a different person."
)
_NO_SIMILARITY = " There is no reference photo: set similarity to 0."


@dataclass
class GeminiInspector:
    """An ImageInspector: the facts the safety rules (safety.judge) need.
    Any doubt fails safe: no answer means the image is not used."""

    client: GeminiClient

    def inspect(self, image: bytes, reference: bytes | None) -> ImageFacts:
        parts: list[dict[str, Any]] = [
            {"text": _INSPECT + (_SIMILARITY if reference is not None else _NO_SIMILARITY)},
            _part(image),
        ]
        if reference is not None:
            parts.append(_part(reference))
        try:
            a = self.client.json_answer(
                {
                    "contents": [{"role": "user", "parts": parts}],
                    "generationConfig": {
                        "responseMimeType": "application/json",
                        "responseSchema": _FACTS_SCHEMA,
                        "temperature": 0,
                    },
                }
            )
            return ImageFacts(
                face_count=int(a["face_count"]),
                looks_under_18=bool(a["looks_under_18"]),
                nudity=bool(a["nudity"]),
                violence=bool(a["violence"]),
                text_or_logo=bool(a["text_or_logo"]),
                similarity=float(a["similarity"]) if reference is not None else None,
            )
        except (GeminiError, KeyError, TypeError, ValueError):
            log.warning("gemini inspection failed; the image is not used")
            return ImageFacts(
                face_count=0,
                looks_under_18=True,
                nudity=False,
                violence=False,
                text_or_logo=False,
            )


_BOX_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "found": {"type": "BOOLEAN"},
        "box_2d": {"type": "ARRAY", "items": {"type": "INTEGER"}},
    },
    "required": ["found", "box_2d"],
}

_LOCATE = (
    "Find the one person's face (forehead to chin, ear to ear, not the hair or "
    "neck). Answer found and box_2d as [ymin, xmin, ymax, xmax] scaled 0 to "
    "1000. If there is no face or more than one, found is false."
)


@dataclass
class GeminiFaceLocator:
    """A FaceLocator: the face's box from Gemini's object detection."""

    client: GeminiClient

    def locate(self, image: Image.Image) -> FaceBox | None:
        try:
            a = self.client.json_answer(
                {
                    "contents": [
                        {"role": "user", "parts": [{"text": _LOCATE}, _part(_png(image))]}
                    ],
                    "generationConfig": {
                        "responseMimeType": "application/json",
                        "responseSchema": _BOX_SCHEMA,
                        "temperature": 0,
                    },
                }
            )
            if not a.get("found"):
                return None
            ymin, xmin, ymax, xmax = (float(v) for v in a["box_2d"])
        except (GeminiError, KeyError, TypeError, ValueError):
            log.warning("gemini face location failed")
            return None
        if not (0 <= xmin < xmax <= 1000 and 0 <= ymin < ymax <= 1000):
            return None
        sx, sy = image.width / 1000, image.height / 1000
        return FaceBox(xmin * sx, ymin * sy, (xmax - xmin) * sx, (ymax - ymin) * sy)
