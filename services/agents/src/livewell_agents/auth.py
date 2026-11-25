"""Who is calling, and whether they agreed to AI processing.

Every request needs a Firebase ID token (Authorization: Bearer) and an App
Check token (X-Firebase-AppCheck), as in services/media. The briefing calls a
model only if the `ai_disclosure` consent is current (checked on the server).
Real checks: firebase_store.py (firebase-admin). Tests use the fakes here.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol


class NotAuthorized(PermissionError):
    pass


#: Needed before any user context goes to a model (consent type in the app:
#: ConsentType.aiDisclosure).
AI_CONSENTS = frozenset({"ai_disclosure"})


class Authenticator(Protocol):
    def uid_for(self, id_token: str, app_check_token: str) -> str:
        """The caller's uid; raises NotAuthorized for a bad or missing token."""
        ...


class ConsentChecker(Protocol):
    def has(self, uid: str, consents: frozenset[str]) -> bool: ...


class NotConfiguredAuthenticator:
    """Refuses everyone until Firebase Admin is wired at deploy."""

    def uid_for(self, id_token: str, app_check_token: str) -> str:
        raise NotAuthorized("authentication is not configured")


class NotConfiguredConsents:
    """Nobody has consented until the consent store is wired."""

    def has(self, uid: str, consents: frozenset[str]) -> bool:
        return False


@dataclass
class FakeAuthenticator:
    """For tests and local dev: ID token 'token-<uid>', App Check 'app-check-ok'."""

    def uid_for(self, id_token: str, app_check_token: str) -> str:
        if app_check_token != "app-check-ok" or not id_token.startswith("token-"):  # noqa: S105
            raise NotAuthorized("bad token")
        uid = id_token.removeprefix("token-")
        if not uid:
            raise NotAuthorized("bad token")
        return uid


@dataclass
class FakeConsents:
    granted: dict[str, set[str]] = field(default_factory=dict)

    def has(self, uid: str, consents: frozenset[str]) -> bool:
        return consents <= self.granted.get(uid, set())
