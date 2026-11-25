"""Hello-world turn traced end to end (T-AGT-01), with nothing personal in
spans or logs (AGENTS.md: ids, counts, durations only)."""

import logging

import pytest

from conftest import make_context
from livewell_agents.tracing import UnsafeTraceAttribute, safe_attrs

SECRET_WHY = "Zebra-violet secret reason about my sister"


def _all_values(spans):
    for s in spans:
        yield s.name
        for v in (s.attributes or {}).values():
            yield from (v if isinstance(v, tuple | list) else [v])


def test_briefing_is_traced_end_to_end(make_service, spans, caplog):
    caplog.set_level(logging.DEBUG)
    service, _, _ = make_service()
    ctx = make_context(
        why=SECRET_WHY,
        last_checkin={"day": "2026-11-18", "mood": 1, "energy": 5, "note": "Quokka note"},
    )
    resp = service.morning(ctx, has_ai_consent=True)
    finished = spans.get_finished_spans()
    names = [s.name for s in finished]
    for expected in [
        "safety.pre",
        "graph.assemble_context",
        "graph.coach_draft",
        "graph.safety_post",
        "graph.finalize",
        "briefing.morning",
    ]:
        assert expected in names
    root = next(s for s in finished if s.name == "briefing.morning")
    assert root.attributes["lw.route"] == "coach"
    assert root.attributes["lw.message_id"] == resp.message.message_id
    assert all(s.context.trace_id == root.context.trace_id for s in finished)
    draft = next(s for s in finished if s.name == "graph.coach_draft")
    assert draft.attributes["lw.prompt_version"] == "coach_briefing@0.1"
    assert draft.attributes["lw.input_tokens"] == 100

    blob = " ".join(str(v) for v in _all_values(finished)) + caplog.text
    for personal in ["Zebra", "sister", "Quokka", "Maya", "Walk after lunch", resp.message.text]:
        assert personal not in blob
    assert not any(k.startswith("lw.mood") for s in finished for k in (s.attributes or {}))


def test_safety_event_traced_without_text(make_service, spans, caplog):
    caplog.set_level(logging.DEBUG)
    service, model, events = make_service()
    resp = service.morning(make_context(why="I don't want to be alive anymore"), True)
    assert resp.route == "safety_template" and model.calls == 0
    pre = next(s for s in spans.get_finished_spans() if s.name == "safety.pre")
    assert pre.attributes["lw.safety.category"] == "crisis"
    assert tuple(pre.attributes["lw.fields"]) == ("why",)
    assert "alive" not in caplog.text
    assert events.events[0].fields == ("why",) and events.events[0].category == "crisis"


@pytest.mark.parametrize(
    "attrs",
    [
        {"lw.reason": "I feel awful today"},
        {"lw.uid": "x" * 200},
        {"lw.mood": 3},
        {"lw.rule_ids": ["ok", "has space"]},
    ],
)
def test_free_text_cannot_enter_a_span(attrs):
    with pytest.raises(UnsafeTraceAttribute):
        safe_attrs(attrs)
