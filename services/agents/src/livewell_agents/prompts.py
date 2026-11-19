"""Prompt registry (spec 9.6): versioned prompt files in services/agents/prompts.

A version is usable only if its file still matches the reviewed sha256, and,
outside dev, only once review_status is "approved" (AGENTS.md rule 9; same
rule as content: prod uses approved only). A Remote Config pointer for the
active version comes with T-AGT-04.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path


class PromptIntegrityError(RuntimeError):
    pass


@dataclass(frozen=True)
class Prompt:
    prompt_id: str
    version: str
    review_status: str
    text: str

    @property
    def tag(self) -> str:
        return f"{self.prompt_id}@{self.version}"


def _body(raw: str) -> str:
    """The prompt text after the `---` metadata block."""
    if raw.startswith("---\n"):
        end = raw.index("\n---\n", 4)
        return raw[end + 5 :].strip()
    return raw.strip()


def file_sha256(path: Path) -> str:
    # Line endings normalised so a Windows checkout hashes the same.
    data = path.read_bytes().replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


class PromptRegistry:
    def __init__(self, prompts_dir: Path) -> None:
        self._dir = prompts_dir
        self._registry = json.loads((prompts_dir / "registry.json").read_text(encoding="utf-8"))

    def active(self, prompt_id: str, allow_pending: bool) -> Prompt | None:
        """The active version, or None when it may not be used here."""
        entry = self._registry["prompts"][prompt_id]
        version = str(entry["active"])
        meta = entry["versions"][version]
        path = self._dir / meta["file"]
        if file_sha256(path) != meta["sha256"]:
            raise PromptIntegrityError(
                f"{prompt_id}@{version} changed after review; add a new version instead"
            )
        status = str(meta["review_status"])
        if status != "approved" and not allow_pending:
            return None
        text = _body(path.read_text(encoding="utf-8").replace("\r\n", "\n"))
        return Prompt(prompt_id, version, status, text)
