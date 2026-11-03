"""Who is calling, and whether they have consented (T-AVT-08c).

Every endpoint needs a Firebase ID token and an App Check token (spec 12.1).
Making an avatar from a selfie also needs the camera and biometric-processing
consents (FR-ONB-03), checked on the server, never trusted from the app.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol


class NotAuthorized(PermissionError):
    pass


class Authenticator(Protocol):
    def uid_for(self, id_token: str, app_check_token: str) -> str:
        """The caller's uid; raises [NotAuthorized] for a bad or missing token."""
        ...


class ConsentChecker(Protocol):
    def has(self, uid: str, consents: frozenset[str]) -> bool:
        """Whether [uid] has granted every consent in [consents] (current,
        not revoked)."""
        ...


#: Needed before a selfie is processed (FR-ONB-03).
SELFIE_CONSENTS = frozenset({"camera", "biometric"})


class NotConfiguredAuthenticator:
    """Refuses everyone until Firebase Admin is wired at deploy time."""

    def uid_for(self, id_token: str, app_check_token: str) -> str:
        raise NotAuthorized("Authentication is not configured")


class NotConfiguredConsents:
    """Nobody has consented until the consent store is wired."""

    def has(self, uid: str, consents: frozenset[str]) -> bool:
        return False


@dataclass
class FakeAuthenticator:
    """For tests: tokens are 'token-<uid>' and App Check 'app-check-ok'."""

    def uid_for(self, id_token: str, app_check_token: str) -> str:
        # Test tokens only; the real check is Firebase Admin at deploy.
        if app_check_token != "app-check-ok" or not id_token.startswith("token-"):  # noqa: S105
            raise NotAuthorized("bad token")
        return id_token.removeprefix("token-")


@dataclass
class FakeConsents:
    granted: dict[str, set[str]] = field(default_factory=dict)

    def has(self, uid: str, consents: frozenset[str]) -> bool:
        return consents <= self.granted.get(uid, set())
