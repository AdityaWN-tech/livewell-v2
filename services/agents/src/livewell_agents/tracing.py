"""Redacted OpenTelemetry spans (spec 9.1 (5), NFR-10, D-90, AGENTS.md).

Span attributes go through `safe_attrs`: an allow-list of keys whose values
are numbers, booleans or short code-like strings (ids, enum values, rule ids,
versions). Free text, mood, health values and model output can't pass: a
value with spaces or longer than 128 characters is refused. Export to Cloud
Trace in our own GCP project comes with deploy (T-FND-10); locally spans can
go to the console (LW_OTEL_CONSOLE=1).
"""

from __future__ import annotations

import re
from collections.abc import Iterator, Mapping, Sequence
from contextlib import contextmanager

from opentelemetry import trace
from opentelemetry.trace import Span

TRACER_NAME = "livewell_agents"

ALLOWED_KEYS = frozenset(
    {
        "lw.uid",
        "lw.flow",
        "lw.node",
        "lw.route",
        "lw.decision",
        "lw.reason",
        "lw.reasons",
        "lw.rule_ids",
        "lw.fields",
        "lw.withheld_fields",
        "lw.safety.category",
        "lw.verdict",
        "lw.attempt",
        "lw.model.provider",
        "lw.model",
        "lw.model.status",
        "lw.model.error",
        "lw.model.request_id",
        "lw.prompt_version",
        "lw.input_tokens",
        "lw.output_tokens",
        "lw.output_chars",
        "lw.message_id",
        "lw.duration_ms",
        "lw.cached",
        "lw.passages",
        "lw.source_ids",
    }
)

_CODE = re.compile(r"^[A-Za-z0-9_.:@/\-]{0,128}$")

AttrValue = str | int | float | bool | Sequence[str]


class UnsafeTraceAttribute(ValueError):
    pass


def safe_attrs(attrs: Mapping[str, AttrValue | None]) -> dict[str, AttrValue]:
    out: dict[str, AttrValue] = {}
    for key, value in attrs.items():
        if key not in ALLOWED_KEYS:
            raise UnsafeTraceAttribute(f"attribute {key!r} is not on the allow-list")
        if value is None:
            continue
        if isinstance(value, bool | int | float):
            out[key] = value
        elif isinstance(value, str):
            if not _CODE.match(value):
                raise UnsafeTraceAttribute(f"attribute {key!r} is not a code-like value")
            out[key] = value
        else:
            items = [str(v) for v in value]
            if not all(_CODE.match(v) for v in items):
                raise UnsafeTraceAttribute(f"attribute {key!r} has a non-code value")
            out[key] = items
    return out


def tracer() -> trace.Tracer:
    return trace.get_tracer(TRACER_NAME)


@contextmanager
def span(name: str, attrs: Mapping[str, AttrValue | None] | None = None) -> Iterator[Span]:
    with tracer().start_as_current_span(name, attributes=safe_attrs(attrs or {})) as s:
        yield s


def set_attrs(s: Span, attrs: Mapping[str, AttrValue | None]) -> None:
    s.set_attributes(safe_attrs(attrs))


def configure_console_tracing() -> None:
    """Local only: print spans (already redacted) to stdout."""
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor

    provider = TracerProvider()
    provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)
