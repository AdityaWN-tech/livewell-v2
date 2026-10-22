"""The AvatarStylizer adapter (T-AVT-08c): the image method sits behind this
interface so it can be swapped (a commercial image API with face reference and
editing, or self-hosted models on our own GPU) without changing the service.

The vendor is chosen with the scorecard in docs/design/avatar-vendor-scorecard.md
(likeness, consistency with the reference, speed, cost per avatar, commercial
licence, data terms). Until then no vendor is configured and nothing is sent
anywhere.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol
from urllib.parse import urlparse


class StylizerError(RuntimeError):
    """The image method failed (the job retries once)."""


class EndpointNotApproved(PermissionError):
    """A user photo would go to an endpoint we have not approved."""


#: Public demo hosts: user photos never go here (T-AVT-08c).
PUBLIC_DEMO_HOSTS = (
    "gradio.live",
    "gradio.app",
    "hf.space",
    "huggingface.co",
    "colab.research.google.com",
    "colab.google",
    "googleusercontent.com",
    "ngrok.io",
    "ngrok-free.app",
    "trycloudflare.com",
    "replit.dev",
)


def check_endpoint(url: str, approved_hosts: frozenset[str]) -> None:
    """Refuses any endpoint that isn't HTTPS to an approved host, and every
    public demo server, even if someone approved it by mistake."""
    parts = urlparse(url)
    host = (parts.hostname or "").lower()
    if parts.scheme != "https" or not host:
        raise EndpointNotApproved(f"Not an HTTPS endpoint: {url}")
    if any(host == h or host.endswith("." + h) for h in PUBLIC_DEMO_HOSTS):
        raise EndpointNotApproved(f"Public demo server: {host}")
    if host not in approved_hosts:
        raise EndpointNotApproved(f"Endpoint not approved: {host}")


@dataclass(frozen=True)
class Generated:
    """One image from the stylizer, and what it cost."""

    image: bytes
    cost_usd: float
    model: str


class AvatarStylizer(Protocol):
    """Makes one adult 3D portrait (or edits one)."""

    #: Where images are sent; checked with [check_endpoint] before any call.
    endpoint: str

    def generate(
        self,
        prompt: str,
        avoid: str,
        reference: bytes | None = None,
    ) -> Generated:
        """A new portrait from [prompt]; [reference] is the person's own
        selfie (From my photo) or the approved portrait (Adjust, frames)."""
        ...


class NotConfiguredStylizer:
    """No vendor chosen yet: refuses every call, sends nothing."""

    endpoint = "https://not-configured.invalid"

    def generate(
        self,
        prompt: str,
        avoid: str,
        reference: bytes | None = None,
    ) -> Generated:
        raise StylizerError("No avatar image vendor is configured (scorecard pending)")


@dataclass
class FakeStylizer:
    """For tests and local development: returns fixed bytes and records the
    prompts it was given. Never leaves the process."""

    endpoint: str = "https://stylizer.test.livewell"
    fail_times: int = 0
    cost_usd: float = 0.04
    calls: list[tuple[str, str, bytes | None]] = field(default_factory=list)

    def generate(
        self,
        prompt: str,
        avoid: str,
        reference: bytes | None = None,
    ) -> Generated:
        self.calls.append((prompt, avoid, reference))
        if self.fail_times > 0:
            self.fail_times -= 1
            raise StylizerError("fake failure")
        return Generated(
            image=b"PORTRAIT-" + str(len(self.calls)).encode(),
            cost_usd=self.cost_usd,
            model="fake-stylizer-1",
        )
