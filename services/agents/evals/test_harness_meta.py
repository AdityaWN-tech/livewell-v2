"""The harness itself (T-AGT-08): it must catch a broken safety layer, keep
known gaps honest and reject a malformed golden set. These tests break the
pipeline on purpose (monkeypatch) and expect the merge gate to fail."""

import json
import logging
import shutil

import pytest

import livewell_agents.coach as coach_mod
import livewell_agents.graph as graph_mod
from evals.harness import load_golden_set, run_and_summarise, run_golden_set
from evals.harness.__main__ import GOLDEN_DIR, default_env, main
from evals.harness.cases import GoldenSetError, KnownGap
from evals.harness.runner import run_case
from livewell_agents.safety.postcheck import PostCheckResult
from livewell_agents.safety.rules import Finding

GOLDEN = load_golden_set(GOLDEN_DIR)


@pytest.fixture
def env():
    return default_env()


def _subset(*categories, known_gaps=None):
    cases = tuple(c for c in GOLDEN.cases if c.category in categories and c.tier == "offline")
    gaps = (
        known_gaps
        if known_gaps is not None
        else {k: v for k, v in GOLDEN.known_gaps.items() if k in {c.id for c in cases}}
    )
    manifest = GOLDEN.manifest.model_copy(update={"min_offline_cases": 1})
    return GOLDEN.model_copy(update={"cases": cases, "known_gaps": gaps, "manifest": manifest})


def test_blind_red_flag_engine_fails_the_gate(env, monkeypatch):
    monkeypatch.setattr(type(env.engine), "check", lambda self, text: Finding(None, ()))
    summary = run_and_summarise(_subset("emergency", "crisis"), env)
    assert not summary["merge_gate"]["passed"]
    assert "critical case(s) failed" in summary["merge_gate"]["reasons"][0]
    assert summary["by_severity"]["critical"]["fail"] >= 80


def test_post_check_that_approves_everything_fails_the_gate(env, monkeypatch):
    approve = PostCheckResult("approve", (), ())
    monkeypatch.setattr(graph_mod, "post_check", lambda draft, engine, **kw: approve)
    summary = run_and_summarise(_subset("medication_output", "cure_claim"), env)
    assert not summary["merge_gate"]["passed"]
    med = next(m for m in summary["metrics_15_2"] if m["name"] == "med_instructions_in_outputs")
    assert med["status"] == "not_met" and med["value"] >= 20


def test_user_text_in_logs_fails_the_gate(env, monkeypatch):
    real = coach_mod.safety_pre
    leaky = logging.getLogger("livewell_agents.leaky")

    def leaking_pre(ctx, engine, now, extra=None):
        leaky.debug("why=%s", ctx.why)
        return real(ctx, engine, now, extra)

    monkeypatch.setattr(coach_mod, "safety_pre", leaking_pre)
    results = run_golden_set(_subset("no_phi_in_logs"), env)
    failed = [r for r in results if r.status == "fail"]
    assert len(failed) >= 10
    assert any("logs/spans contain" in f for r in failed for f in r.failures)


def test_skipped_consent_check_fails_the_gate(env, monkeypatch):
    class NoConsent(Exception):
        pass

    monkeypatch.setattr(coach_mod, "ConsentRequired", NoConsent)  # never raised as expected
    summary = run_and_summarise(_subset("ai_consent"), env)
    assert not summary["merge_gate"]["passed"]


def test_a_known_gap_that_passes_is_stale(env):
    case = next(c for c in GOLDEN.cases if c.id == "em-chest-arm-us")
    gap = KnownGap(
        id=case.id,
        severity=case.severity,
        reason="pretend gap for the test",
        owner_task="T-AGT-08",
        added="2026-11-21",
    )
    golden = _subset("emergency", known_gaps={case.id: gap})
    assert run_case(case, env, golden, "offline").status == "stale_gap"
    summary = run_and_summarise(golden, env)
    assert not summary["merge_gate"]["passed"]
    assert any("now pass" in r for r in summary["merge_gate"]["reasons"])


def test_critical_known_gap_blocks_release_not_merge(env):
    golden = _subset("emergency")
    summary = run_and_summarise(golden, env)
    assert summary["merge_gate"]["passed"]
    if summary["by_severity"]["critical"]["known_gap"]:
        assert not summary["release_gate"]["passed"]
        routing = summary["metrics_15_2"][0]
        assert routing["name"] == "critical_safety_routing" and routing["value"] < 1.0


def test_unknown_target_is_an_error(env):
    case = GOLDEN.cases[0].model_copy(update={"target": "no_such_target"})
    assert run_case(case, env, GOLDEN, "offline").status == "error"


def test_live_cases_are_skipped_offline(env):
    live = [c for c in GOLDEN.cases if c.tier == "live"]
    assert live
    assert all(run_case(c, env, GOLDEN, "offline").status == "skipped" for c in live)
    # Even in a live run without a model, a live case never counts as a pass.
    assert run_case(live[0], env, GOLDEN, "live").status == "skipped"


def test_too_few_cases_fails_the_gate(env):
    golden = _subset("ai_consent")
    golden = golden.model_copy(
        update={"manifest": golden.manifest.model_copy(update={"min_offline_cases": 300})}
    )
    assert not run_and_summarise(golden, env)["merge_gate"]["passed"]


# ---------------------------------------------------------------- loader


@pytest.fixture
def golden_copy(tmp_path):
    dst = tmp_path / "golden"
    shutil.copytree(GOLDEN_DIR, dst)
    return dst


def _edit_gaps(folder, fn):
    path = folder / "known_gaps.json"
    data = json.loads(path.read_text())
    fn(data["gaps"])
    path.write_text(json.dumps(data))


def test_loader_rejects_duplicate_ids(golden_copy):
    path = golden_copy / "safety_emergency.jsonl"
    first = path.read_text().splitlines()[0]
    path.write_text(path.read_text() + first + "\n")
    with pytest.raises(GoldenSetError, match="duplicate"):
        load_golden_set(golden_copy)


def test_loader_rejects_gap_that_downgrades_severity(golden_copy):
    def downgrade(gaps):
        # A gap entry for a critical case that claims a lower severity (no
        # critical gap is left in the real list since D-96).
        gaps.append({**gaps[0], "id": "em-chest-squeeze-us", "severity": "normal"})

    _edit_gaps(golden_copy, downgrade)
    with pytest.raises(GoldenSetError, match="severity"):
        load_golden_set(golden_copy)


def test_loader_rejects_gap_for_unknown_case(golden_copy):
    _edit_gaps(golden_copy, lambda g: g.append({**g[0], "id": "no-such-case"}))
    with pytest.raises(GoldenSetError, match="unknown case"):
        load_golden_set(golden_copy)


def test_loader_rejects_unlisted_file(golden_copy):
    (golden_copy / "stray.jsonl").write_text("")
    with pytest.raises(GoldenSetError, match="not listed"):
        load_golden_set(golden_copy)


def test_loader_rejects_unknown_category(golden_copy):
    path = golden_copy / "cure_claims.jsonl"
    case = json.loads(path.read_text().splitlines()[0])
    case.update({"id": "bad-category", "category": "vibes"})
    path.write_text(path.read_text() + json.dumps(case) + "\n")
    with pytest.raises(GoldenSetError, match="unknown category"):
        load_golden_set(golden_copy)


def test_cli_writes_summary(tmp_path, capsys):
    out_json, out_md = tmp_path / "s.json", tmp_path / "s.md"
    assert main(["--json", str(out_json), "--markdown", str(out_md)]) == 0
    summary = json.loads(out_json.read_text())
    assert summary["merge_gate"]["passed"]
    assert summary["cases"]["offline"] >= 300
    assert {m["name"] for m in summary["metrics_15_2"]} >= {
        "critical_safety_routing",
        "med_instructions_in_outputs",
        "schema_validity",
    }
    assert "Merge gate: **PASS**" in out_md.read_text()


def test_cli_rejects_bad_golden_set(golden_copy):
    (golden_copy / "stray.jsonl").write_text("")
    assert main(["--golden", str(golden_copy)]) == 2


# ---------------------------------------------------------------- T-AGT-04 coach target


def _mode_subset(mode, *categories):
    sub = _subset(*categories)
    cases = tuple(c for c in sub.cases if c.input.get("mode") == mode)
    return sub.model_copy(update={"cases": cases, "known_gaps": {}})


@pytest.mark.parametrize("mode", ["reply", "nudge", "reflection", "weekly_review"])
def test_blind_rules_fail_the_gate_in_every_mode(env, monkeypatch, mode):
    monkeypatch.setattr(type(env.engine), "check", lambda self, text: Finding(None, ()))
    summary = run_and_summarise(_mode_subset(mode, "emergency", "crisis"), env)
    assert not summary["merge_gate"]["passed"]
    assert summary["by_severity"]["critical"]["fail"] >= 6


def test_grounding_check_that_approves_everything_fails_the_gate(env, monkeypatch):
    approve = PostCheckResult("approve", (), (), ("source_presence",))
    monkeypatch.setattr(graph_mod, "grounding_check", lambda draft, provided: approve)
    summary = run_and_summarise(_mode_subset("reply", "grounding"), env)
    assert not summary["merge_gate"]["passed"]


def test_nudge_privacy_check_removed_fails_the_gate(env, monkeypatch):
    approve = PostCheckResult("approve", (), (), ("lock_screen_privacy",))
    monkeypatch.setattr(graph_mod, "personal_text_check", lambda draft, personal: approve)
    summary = run_and_summarise(_mode_subset("nudge", "no_phi_in_logs"), env)
    assert not summary["merge_gate"]["passed"]


def test_request_text_not_screened_fails_the_gate(env, monkeypatch):
    real = coach_mod.safety_pre

    def ignores_request(ctx, engine, now, extra=None):
        return real(ctx, engine, now)

    monkeypatch.setattr(coach_mod, "safety_pre", ignores_request)
    summary = run_and_summarise(_mode_subset("reply", "emergency", "crisis"), env)
    assert not summary["merge_gate"]["passed"]
