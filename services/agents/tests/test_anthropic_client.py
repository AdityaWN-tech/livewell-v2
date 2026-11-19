"""AnthropicModelClient against a stub SDK client (no network, no key)."""

from types import SimpleNamespace

import anthropic
import httpx2
import pytest

from livewell_agents.anthropic_client import FALLBACK_BETA, AnthropicModelClient
from livewell_agents.model_client import ModelRequest
from livewell_agents.models import COACH_DRAFT_JSON_SCHEMA

REQ = ModelRequest("coach_briefing", "system text", "user text", COACH_DRAFT_JSON_SCHEMA)


class StubMessages:
    def __init__(self, response=None, error=None):
        self.response, self.error, self.kwargs = response, error, None

    def create(self, **kwargs):
        self.kwargs = kwargs
        if self.error:
            raise self.error
        return self.response


def _client(response=None, error=None):
    messages = StubMessages(response, error)
    sdk = SimpleNamespace(beta=SimpleNamespace(messages=messages))
    return AnthropicModelClient("claude-opus-5-5", "low", 16000, 60, client=sdk), messages


def _response(stop_reason="end_turn", text='{"text": "hi", "emotion": "calm"}', details=None):
    return SimpleNamespace(
        model="claude-opus-5-5",
        stop_reason=stop_reason,
        stop_details=details,
        usage=SimpleNamespace(input_tokens=11, output_tokens=7),
        content=[
            SimpleNamespace(type="thinking", thinking=""),
            SimpleNamespace(type="text", text=text),
        ],
    )


def test_request_shape():
    client, messages = _client(_response())
    result = client.generate(REQ)
    k = messages.kwargs
    assert k["model"] == "claude-opus-5-5"
    assert k["thinking"] == {"type": "adaptive"}
    assert k["output_config"]["effort"] == "low"
    assert k["output_config"]["format"] == {
        "type": "json_schema",
        "schema": COACH_DRAFT_JSON_SCHEMA,
    }
    assert k["fallbacks"] == "default" and k["betas"] == [FALLBACK_BETA]
    assert k["system"] == "system text"
    assert k["messages"] == [{"role": "user", "content": "user text"}]
    assert "temperature" not in k
    assert result.status == "ok" and result.text == '{"text": "hi", "emotion": "calm"}'
    assert result.model == "anthropic/claude-opus-5-5" and result.input_tokens == 11


def test_refusal_checked_before_content():
    details = SimpleNamespace(category="bio", explanation="x")
    client, _ = _client(_response("refusal", text="partial", details=details))
    result = client.generate(REQ)
    assert result.status == "refusal" and result.text == "" and result.error == "refusal:bio"


def test_max_tokens_is_truncated():
    client, _ = _client(_response("max_tokens"))
    assert client.generate(REQ).status == "truncated"


REQUEST = httpx2.Request("POST", "https://api.anthropic.com/v1/messages")


def _status_error(cls, code):
    return cls("boom", response=httpx2.Response(code, request=REQUEST), body=None)


@pytest.mark.parametrize(
    ("error", "name"),
    [
        (lambda: _status_error(anthropic.BadRequestError, 400), "BadRequestError"),
        (lambda: _status_error(anthropic.RateLimitError, 429), "RateLimitError"),
        (lambda: _status_error(anthropic.InternalServerError, 500), "InternalServerError"),
        (lambda: anthropic.APIConnectionError(request=REQUEST), "APIConnectionError"),
        (lambda: anthropic.APITimeoutError(request=REQUEST), "APITimeoutError"),
    ],
)
def test_sdk_errors_become_error_results(error, name):
    client, _ = _client(error=error())
    result = client.generate(REQ)
    assert result.status == "error" and result.error == name and result.text == ""
