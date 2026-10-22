"""The image safety check on every result (T-AVT-08c).

Rejects child-looking faces (adults only), nudity, violence and text or logos;
for a selfie avatar it also rejects a result that doesn't look like the person
(face similarity below the threshold). Behind an interface: the checking model
or vendor is chosen with the same scorecard as the stylizer.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Protocol


class Rejection(StrEnum):
    CHILD_LOOKING = "child_looking"
    NUDITY = "nudity"
    VIOLENCE = "violence"
    TEXT_OR_LOGO = "text_or_logo"
    NOT_THE_PERSON = "not_the_person"
    NO_FACE = "no_face"


@dataclass(frozen=True)
class SafetyVerdict:
    reasons: frozenset[Rejection] = frozenset()

    @property
    def ok(self) -> bool:
        return not self.reasons


@dataclass(frozen=True)
class ImageFacts:
    """What the checking model reports about one image."""

    face_count: int
    looks_under_18: bool
    nudity: bool
    violence: bool
    text_or_logo: bool
    #: 0 to 1 against the selfie; None when there is no selfie.
    similarity: float | None = None


class ImageInspector(Protocol):
    """The checking model (vendor or self-hosted) behind the safety check."""

    def inspect(self, image: bytes, reference: bytes | None) -> ImageFacts: ...


def judge(facts: ImageFacts, *, selfie: bool, min_similarity: float) -> SafetyVerdict:
    """The rules, as plain code: any one reason rejects the image."""
    reasons: set[Rejection] = set()
    if facts.face_count != 1:
        reasons.add(Rejection.NO_FACE)
    if facts.looks_under_18:
        reasons.add(Rejection.CHILD_LOOKING)
    if facts.nudity:
        reasons.add(Rejection.NUDITY)
    if facts.violence:
        reasons.add(Rejection.VIOLENCE)
    if facts.text_or_logo:
        reasons.add(Rejection.TEXT_OR_LOGO)
    if selfie and (facts.similarity is None or facts.similarity < min_similarity):
        reasons.add(Rejection.NOT_THE_PERSON)
    return SafetyVerdict(frozenset(reasons))


class NotConfiguredInspector:
    """No checking model chosen yet: nothing passes."""

    def inspect(self, image: bytes, reference: bytes | None) -> ImageFacts:
        return ImageFacts(
            face_count=0,
            looks_under_18=True,
            nudity=False,
            violence=False,
            text_or_logo=False,
        )


@dataclass
class FakeInspector:
    """For tests: reports the facts it is given, in order (the last repeats)."""

    results: list[ImageFacts] = field(
        default_factory=lambda: [
            ImageFacts(
                face_count=1,
                looks_under_18=False,
                nudity=False,
                violence=False,
                text_or_logo=False,
                similarity=0.9,
            )
        ]
    )
    seen: int = 0

    def inspect(self, image: bytes, reference: bytes | None) -> ImageFacts:
        facts = self.results[min(self.seen, len(self.results) - 1)]
        self.seen += 1
        return facts
