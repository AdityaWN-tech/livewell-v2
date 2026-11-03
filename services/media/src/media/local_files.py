"""Frame sets on the Media Service's own disk, for development without
Cloud Storage (D-64). Prod keeps them in Cloud Storage avatars/{uid}/{version}/
with V4 signed URLs from the Core API; this does the same job locally:
files under MEDIA_FRAMES_DIR, and short-lived links signed with an HMAC key
so the app can download them without sending its ID token to a file URL.
"""

from __future__ import annotations

import hashlib
import hmac
import re
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

#: Frame files are named by the frame builder (neutral@3x.webp,
#: thumb_happy.png, avatar_frames.json); nothing else is ever served.
_NAME = re.compile(r"^[A-Za-z0-9_]+(@[23]x)?\.(webp|png|json)$")
#: Firebase uids: letters and digits (28 characters in practice).
_UID = re.compile(r"^[A-Za-z0-9]{1,128}$")


def valid_name(name: str) -> bool:
    return bool(_NAME.match(name))


def valid_uid(uid: str) -> bool:
    return bool(_UID.match(uid))


@dataclass
class LocalFrameStore:
    """A FrameStore on disk: <root>/<uid>/<version>/<name>."""

    root: Path

    def _dir(self, uid: str, version: int) -> Path:
        if not valid_uid(uid) or version < 1:
            raise ValueError("bad frame set address")
        return self.root / uid / str(version)

    def next_version(self, uid: str) -> int:
        if not valid_uid(uid):
            raise ValueError("bad uid")
        folder = self.root / uid
        if not folder.exists():
            return 1
        return max((int(p.name) for p in folder.iterdir() if p.name.isdigit()), default=0) + 1

    def put(self, uid: str, version: int, name: str, data: bytes) -> None:
        if not valid_name(name):
            raise ValueError("bad frame file name")
        folder = self._dir(uid, version)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / name).write_bytes(data)

    def names(self, uid: str, version: int) -> list[str]:
        folder = self._dir(uid, version)
        if not folder.is_dir():
            return []
        return sorted(p.name for p in folder.iterdir() if p.is_file() and valid_name(p.name))

    def read(self, uid: str, version: int, name: str) -> bytes | None:
        if not valid_name(name):
            return None
        path = self._dir(uid, version) / name
        return path.read_bytes() if path.is_file() else None


@dataclass
class FrameLinks:
    """Signs and checks the download links: /v1/avatar/files/... with an
    expiry and an HMAC of the path, like a signed Cloud Storage URL."""

    key: bytes = field(repr=False)
    ttl_s: int = 15 * 60
    clock: Callable[[], float] = time.time

    def _sig(self, uid: str, version: int, name: str, exp: int) -> str:
        msg = f"{uid}/{version}/{name}/{exp}".encode()
        return hmac.new(self.key, msg, hashlib.sha256).hexdigest()

    def path(self, uid: str, version: int, name: str) -> str:
        exp = int(self.clock()) + self.ttl_s
        sig = self._sig(uid, version, name, exp)
        return f"v1/avatar/files/{uid}/{version}/{name}?exp={exp}&sig={sig}"

    def ok(self, uid: str, version: int, name: str, exp: int, sig: str) -> bool:
        if exp < self.clock():
            return False
        return hmac.compare_digest(self._sig(uid, version, name, exp), sig)
