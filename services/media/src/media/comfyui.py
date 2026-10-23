"""The ComfyUI stylizer: our own ComfyUI server (on a private Cloud Run GPU,
docs/media/comfyui-setup.md) with open models downloaded from Hugging Face.

One image is one ComfyUI job: upload the input image (the selfie, the
approved portrait or the neutral frame), send a workflow from
services/media/workflows/ with the prompt filled in, wait for the job,
download the result, then ask the server to forget the input, the output and
the job's history. The safety check, frame alignment and storage happen after
this, in the job runner and the frame builder, exactly as for any stylizer.

Only the Media Service talks to ComfyUI: the phone never does, and user photos
never go to a public demo server (check_endpoint refuses those even if someone
approved one by mistake). The URL and keys come from environment variables
that Cloud Run fills from Secret Manager. Nothing personal is logged: job ids
and statuses only, never prompts, file names or images.
"""

from __future__ import annotations

import copy
import json
import logging
import secrets
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

import httpx

from .stylizer import Generated, StylizerError, check_endpoint

log = logging.getLogger("media")

POSITIVE = "{{POSITIVE}}"
NEGATIVE = "{{NEGATIVE}}"
INPUT_IMAGE = "{{INPUT_IMAGE}}"
SEED = "{{SEED}}"

#: The workflows this service ships (services/media/workflows/).
WORKFLOWS = Path(__file__).resolve().parents[2] / "workflows"


class WorkflowError(ValueError):
    """A workflow file that can't be used (checked when the service starts)."""


def _walk(node: object) -> list[str]:
    """Every string in a JSON value."""
    if isinstance(node, str):
        return [node]
    if isinstance(node, dict):
        return [s for v in node.values() for s in _walk(v)]
    if isinstance(node, list):
        return [s for v in node for s in _walk(v)]
    return []


@dataclass(frozen=True)
class Workflow:
    """A workflow file: ComfyUI API-format graphs with placeholders.

    `graphs.image` is used when there is an input image, `graphs.text` when
    there isn't (Build my own). `output_node` is the SaveImage node whose
    image is the result. `models` lists the files the server must have.
    """

    name: str
    version: int
    output_node: str
    graphs: dict[str, dict[str, Any]]
    models: tuple[str, ...]

    @classmethod
    def load(cls, path: Path) -> Workflow:
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            wf = cls(
                name=str(raw["name"]),
                version=int(raw["version"]),
                output_node=str(raw["output_node"]),
                graphs={k: dict(v) for k, v in raw["graphs"].items()},
                models=tuple(str(m["file"]) for m in raw["models"]),
            )
        except (KeyError, TypeError, ValueError, AttributeError) as e:
            raise WorkflowError(f"{path.name}: {e}") from None
        wf._check(path.name)
        return wf

    def _check(self, file: str) -> None:
        if not self.graphs or set(self.graphs) - {"image", "text"}:
            raise WorkflowError(f"{file}: graphs must be 'image' and/or 'text'")
        for kind, graph in self.graphs.items():
            if self.output_node not in graph:
                raise WorkflowError(f"{file}: {kind} graph has no output node")
            strings = _walk(graph)
            for needed in (POSITIVE, NEGATIVE, SEED):
                if not any(needed in s for s in strings):
                    raise WorkflowError(f"{file}: {kind} graph has no {needed}")
            has_input = INPUT_IMAGE in strings
            if has_input != (kind == "image"):
                raise WorkflowError(f"{file}: only the image graph takes {INPUT_IMAGE}")

    def fill(self, positive: str, negative: str, image: str | None, seed: int) -> dict[str, Any]:
        """The graph to send, with the placeholders filled in. Works on the
        parsed JSON, so prompt text can never change the graph's shape."""
        kind = "image" if image is not None else "text"
        if kind not in self.graphs:
            raise StylizerError(f"Workflow {self.name} needs an input image")

        def sub(node: object) -> object:
            if isinstance(node, dict):
                return {k: sub(v) for k, v in node.items()}
            if isinstance(node, list):
                return [sub(v) for v in node]
            if node == SEED:
                return seed
            if node == INPUT_IMAGE:
                return image
            if isinstance(node, str):
                return node.replace(POSITIVE, positive).replace(NEGATIVE, negative)
            return node

        filled = sub(copy.deepcopy(self.graphs[kind]))
        assert isinstance(filled, dict)
        return filled


class ComfyAuth(Protocol):
    """Headers that prove the caller is the Media Service."""

    def headers(self) -> dict[str, str]: ...


#: Cloud Run's metadata server: an ID token for this service's identity.
METADATA_IDENTITY = (
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity"
)


@dataclass
class GoogleIdToken:
    """The main option: ComfyUI runs as a private Cloud Run service that
    only the Media Service's service account may invoke (roles/run.invoker).
    The token comes from the metadata server and is kept until shortly
    before it expires (Google ID tokens last an hour)."""

    audience: str
    fetch: Callable[[str], str] | None = None
    lifetime_s: float = 50 * 60
    now: Callable[[], float] = time.monotonic
    _token: str = ""
    _until: float = 0.0
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def _from_metadata(self, audience: str) -> str:
        r = httpx.get(
            METADATA_IDENTITY,
            params={"audience": audience},
            headers={"Metadata-Flavor": "Google"},
            timeout=10,
        )
        r.raise_for_status()
        return r.text.strip()

    def headers(self) -> dict[str, str]:
        with self._lock:
            if not self._token or self.now() >= self._until:
                try:
                    self._token = (self.fetch or self._from_metadata)(self.audience)
                except httpx.HTTPError:
                    raise StylizerError("No ID token for ComfyUI") from None
                self._until = self.now() + self.lifetime_s
            return {"Authorization": f"Bearer {self._token}"}


@dataclass(frozen=True)
class ApiKeyHeader:
    """The fallback: a key in a header, checked by a gateway in front of
    ComfyUI (ComfyUI itself has no login). The key is a Secret Manager
    secret, never in the repo."""

    key: str = field(repr=False)
    header: str = "X-Api-Key"

    def headers(self) -> dict[str, str]:
        return {self.header: self.key}


def _image_name(data: bytes) -> tuple[str, str]:
    """A random file name (nothing about the person) and the image type."""
    token = secrets.token_hex(12)
    if data.startswith(b"\xff\xd8\xff"):
        return f"lw-{token}.jpg", "image/jpeg"
    if data.startswith(b"\x89PNG"):
        return f"lw-{token}.png", "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return f"lw-{token}.webp", "image/webp"
    raise StylizerError("Input is not a JPEG, PNG or WebP image")


@dataclass
class ComfyUIStylizer:
    """An AvatarStylizer backed by our ComfyUI server and one workflow."""

    endpoint: str
    workflow: Workflow
    auth: ComfyAuth
    approved_hosts: frozenset[str]
    #: Longest wait for one image, queue time included (a cold start loads
    #: the models first: see comfyui-setup.md).
    timeout_s: float = 600
    poll_every_s: float = 1.5
    #: GPU + CPU + memory per second of the ComfyUI service, for the cost
    #: record (0 until the rates are set; see comfyui-setup.md).
    usd_per_second: float = 0.0
    #: For tests: a transport instead of the network.
    transport: httpx.BaseTransport | None = None
    sleep: Callable[[float], None] = time.sleep
    clock: Callable[[], float] = time.monotonic

    def _client(self) -> httpx.Client:
        # One client per image: its cookies keep Cloud Run session affinity,
        # so the upload, the job and the download reach the same instance.
        return httpx.Client(
            base_url=self.endpoint.rstrip("/"),
            headers=self.auth.headers(),
            timeout=httpx.Timeout(60, connect=20),
            transport=self.transport,
            follow_redirects=False,
        )

    def generate(self, prompt: str, avoid: str, reference: bytes | None = None) -> Generated:
        # Checked here too, not only by the callers.
        check_endpoint(self.endpoint, self.approved_hosts)
        started = self.clock()
        files: list[dict[str, str]] = []
        prompt_id: str | None = None
        try:
            with self._client() as http:
                try:
                    image = None
                    if reference is not None:
                        uploaded = self._upload(http, reference)
                        files.append(uploaded)
                        image = uploaded["name"]
                    graph = self.workflow.fill(prompt, avoid, image, secrets.randbelow(2**31))
                    prompt_id = self._queue(http, graph)
                    outputs = self._wait(http, prompt_id)
                    files.extend(outputs)
                    if not outputs:
                        raise StylizerError("ComfyUI made no image")
                    result = self._download(http, outputs[0])
                finally:
                    self._forget(http, prompt_id, files)
        except httpx.HTTPError:
            raise StylizerError("ComfyUI could not be reached") from None
        seconds = self.clock() - started
        log.info("comfyui %s: image in %.1fs", self.workflow.name, seconds)
        return Generated(
            image=result,
            cost_usd=round(seconds * self.usd_per_second, 6),
            model=f"comfyui:{self.workflow.name}@{self.workflow.version}",
        )

    def _upload(self, http: httpx.Client, data: bytes) -> dict[str, str]:
        name, mime = _image_name(data)
        r = http.post(
            "/upload/image",
            files={"image": (name, data, mime)},
            data={"type": "input", "overwrite": "true"},
        )
        if r.status_code != 200:
            raise StylizerError(f"ComfyUI upload refused ({r.status_code})")
        body = r.json()
        return {
            "name": str(body.get("name", name)),
            "subfolder": str(body.get("subfolder", "")),
            "type": "input",
        }

    def _queue(self, http: httpx.Client, graph: dict[str, Any]) -> str:
        r = http.post("/prompt", json={"prompt": graph, "client_id": secrets.token_hex(8)})
        if r.status_code != 200:
            # The reply may echo the graph: not logged.
            raise StylizerError(f"ComfyUI refused the workflow ({r.status_code})")
        prompt_id = r.json().get("prompt_id")
        if not isinstance(prompt_id, str) or not prompt_id:
            raise StylizerError("ComfyUI gave no job id")
        return prompt_id

    def _wait(self, http: httpx.Client, prompt_id: str) -> list[dict[str, str]]:
        deadline = self.clock() + self.timeout_s
        while True:
            r = http.get(f"/history/{prompt_id}")
            if r.status_code != 200:
                raise StylizerError(f"ComfyUI history failed ({r.status_code})")
            entry = r.json().get(prompt_id)
            if entry:
                status = entry.get("status") or {}
                if status.get("status_str") == "error":
                    raise StylizerError("The ComfyUI job failed")
                if status.get("completed", True):
                    node = (entry.get("outputs") or {}).get(self.workflow.output_node) or {}
                    return [
                        {
                            "name": str(i["filename"]),
                            "subfolder": str(i.get("subfolder", "")),
                            "type": str(i.get("type", "output")),
                        }
                        for i in node.get("images", [])
                    ]
            if self.clock() >= deadline:
                # Take it off the queue so the GPU doesn't spend time on it.
                http.post("/queue", json={"delete": [prompt_id]})
                raise StylizerError("The ComfyUI job took too long")
            self.sleep(self.poll_every_s)

    def _download(self, http: httpx.Client, image: dict[str, str]) -> bytes:
        r = http.get(
            "/view",
            params={
                "filename": image["name"],
                "subfolder": image["subfolder"],
                "type": image["type"],
            },
        )
        if r.status_code != 200 or not r.content:
            raise StylizerError(f"ComfyUI image download failed ({r.status_code})")
        return r.content

    def _forget(
        self, http: httpx.Client, prompt_id: str | None, files: list[dict[str, str]]
    ) -> None:
        """Asks ComfyUI to delete the input and output images and the job's
        history (services/media/comfyui/livewell_forget). Best effort: the
        instance's disk is in memory and is wiped when it scales to zero."""
        if prompt_id is None and not files:
            return
        try:
            if files:
                r = http.post("/livewell/forget", json={"files": files})
                if r.status_code != 200:
                    log.warning("comfyui forget refused (%s)", r.status_code)
            if prompt_id is not None:
                http.post("/history", json={"delete": [prompt_id]})
        except httpx.HTTPError:
            log.warning("comfyui forget failed")


@dataclass(frozen=True)
class ComfyUISettings:
    """From the environment; Cloud Run fills the secret ones from Secret
    Manager (--set-secrets), so they are never in the repo or the image."""

    url: str
    #: id_token (main option) or api_key (fallback).
    auth: str = "id_token"
    api_key: str = field(default="", repr=False)
    api_key_header: str = "X-Api-Key"
    timeout_s: float = 600
    usd_per_second: float = 0.0

    @classmethod
    def from_env(cls, env: dict[str, str]) -> ComfyUISettings | None:
        url = env.get("MEDIA_COMFYUI_URL", "").strip()
        if not url:
            return None
        return cls(
            url=url,
            auth=env.get("MEDIA_COMFYUI_AUTH", "id_token").strip(),
            api_key=env.get("MEDIA_COMFYUI_API_KEY", "").strip(),
            api_key_header=env.get("MEDIA_COMFYUI_API_KEY_HEADER", "X-Api-Key").strip(),
            timeout_s=float(env.get("MEDIA_COMFYUI_TIMEOUT_S", "600")),
            usd_per_second=float(env.get("MEDIA_COMFYUI_USD_PER_SECOND", "0")),
        )

    def authenticator(self) -> ComfyAuth:
        if self.auth == "api_key":
            if not self.api_key:
                raise WorkflowError("MEDIA_COMFYUI_API_KEY is empty")
            return ApiKeyHeader(self.api_key, self.api_key_header)
        if self.auth == "id_token":
            # The audience is the service's own URL (Cloud Run checks it).
            return GoogleIdToken(audience=self.url.rstrip("/"))
        raise WorkflowError(f"Unknown MEDIA_COMFYUI_AUTH: {self.auth}")


def comfyui_stylizers(
    settings: ComfyUISettings,
    approved_hosts: frozenset[str],
    workflows: Path = WORKFLOWS,
    transport: httpx.BaseTransport | None = None,
) -> tuple[ComfyUIStylizer, ComfyUIStylizer]:
    """The portrait stylizer (selfie, Build my own, Adjust) and the frame
    stylizer (the 14 frames), sharing one server and one identity."""
    auth = settings.authenticator()

    def one(file: str) -> ComfyUIStylizer:
        return ComfyUIStylizer(
            endpoint=settings.url,
            workflow=Workflow.load(workflows / file),
            auth=auth,
            approved_hosts=approved_hosts,
            timeout_s=settings.timeout_s,
            usd_per_second=settings.usd_per_second,
            transport=transport,
        )

    return one("avatar_portrait.json"), one("avatar_frames.json")
