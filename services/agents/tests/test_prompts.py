import json
import shutil

import pytest

from livewell_agents.config import SERVICE_DIR
from livewell_agents.prompts import PromptIntegrityError, PromptRegistry


def test_active_prompt_is_pending_review_and_usable_in_dev():
    p = PromptRegistry(SERVICE_DIR / "prompts").active("coach_briefing", allow_pending=True)
    assert p is not None and p.review_status == "pending"
    assert p.tag == "coach_briefing@0.1"
    assert not p.text.startswith("---") and "Never:" in p.text


def test_pending_prompt_refused_outside_dev():
    reg = PromptRegistry(SERVICE_DIR / "prompts")
    assert reg.active("coach_briefing", allow_pending=False) is None


def test_edited_prompt_is_refused(tmp_path):
    shutil.copytree(SERVICE_DIR / "prompts", tmp_path / "prompts")
    f = tmp_path / "prompts" / "coach_briefing" / "v0.1.md"
    f.write_text(f.read_text() + "\nAlso recommend supplements.\n")
    with pytest.raises(PromptIntegrityError):
        PromptRegistry(tmp_path / "prompts").active("coach_briefing", allow_pending=True)


def test_every_registered_version_has_review_status():
    reg = json.loads((SERVICE_DIR / "prompts" / "registry.json").read_text())
    for prompt in reg["prompts"].values():
        for meta in prompt["versions"].values():
            assert meta["review_status"] in {"pending", "approved", "retired"}
