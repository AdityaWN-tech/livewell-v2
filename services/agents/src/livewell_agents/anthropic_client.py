"""AnthropicModelClient: Claude through the official `anthropic` SDK (D-90).

- Key: ANTHROPIC_API_KEY from the environment only. Locally that is a
  git-ignored .env; on Cloud Run it is a Secret Manager secret mapped to the
  env var (`--set-secrets ANTHROPIC_API_KEY=<secret>:latest`). Never in code.
- Model: LW_ANTHROPIC_MODEL (default claude-opus-5-5). Adaptive thinking (it
  cannot be turned off on this model), effort set explicitly (LW_ANTHROPIC_EFFORT,
  default "low" for a short briefing).
- Structured output: output_config.format with the CoachDraft JSON schema; we
  still validate the JSON ourselves and retry once (T-AGT-01).
- Refusals: stop_reason "refusal" is checked before reading content, and the
  server-side fallback beta (`fallbacks: "default"`) is on, so a classifier
  decline is retried on Anthropic's recommended fallback model.
- Errors: a typed SDK exception chain; only the class name leaves this module.
"""

from __future__ import annotations

import logging
import os

import anthropic

from livewell_agents.config import Effort
from livewell_agents.model_client import ModelRequest, ModelResult, ModelStatus

log = logging.getLogger("livewell_agents.anthropic")

FALLBACK_BETA = "server-side-fallback-2026-07-01"


class MissingApiKey(RuntimeError):
    pass


class AnthropicModelClient:
    def __init__(
        self,
        model: str,
        effort: Effort,
        max_tokens: int,
        timeout_s: float,
        client: anthropic.Anthropic | None = None,
    ) -> None:
        if client is None:
            if not os.environ.get("ANTHROPIC_API_KEY"):
                raise MissingApiKey(
                    "ANTHROPIC_API_KEY is not set (local: .env; Cloud Run: Secret Manager)"
                )
            client = anthropic.Anthropic(timeout=timeout_s, max_retries=2)
        self._client = client
        self._model = model
        self._effort: Effort = effort
        self._max_tokens = max_tokens

    @property
    def provider(self) -> str:
        return "anthropic"

    def generate(self, request: ModelRequest) -> ModelResult:
        try:
            response = self._client.beta.messages.create(
                model=self._model,
                max_tokens=self._max_tokens,
                system=request.system,
                messages=[{"role": "user", "content": request.user}],
                thinking={"type": "adaptive"},
                output_config={
                    "effort": self._effort,
                    "format": {"type": "json_schema", "schema": request.json_schema},
                },
                betas=[FALLBACK_BETA],
                fallbacks="default",
            )
        except anthropic.BadRequestError as e:
            return self._error(e)
        except anthropic.AuthenticationError as e:
            return self._error(e)
        except anthropic.PermissionDeniedError as e:
            return self._error(e)
        except anthropic.NotFoundError as e:
            return self._error(e)
        except anthropic.RateLimitError as e:
            return self._error(e)
        except anthropic.APIStatusError as e:
            return self._error(e)
        except anthropic.APITimeoutError as e:
            return self._error(e)
        except anthropic.APIConnectionError as e:
            return self._error(e)

        served = f"anthropic/{response.model}"
        request_id = getattr(response, "_request_id", None)
        tokens_in, tokens_out = response.usage.input_tokens, response.usage.output_tokens
        if response.stop_reason == "refusal":
            category = response.stop_details.category if response.stop_details else None
            return ModelResult(
                "refusal",
                "",
                served,
                tokens_in,
                tokens_out,
                error=f"refusal:{category}",
                request_id=request_id,
            )
        text = "".join(block.text for block in response.content if block.type == "text")
        status: ModelStatus = "truncated" if response.stop_reason == "max_tokens" else "ok"
        return ModelResult(status, text, served, tokens_in, tokens_out, request_id=request_id)

    def _error(self, e: anthropic.APIError) -> ModelResult:
        status_code = getattr(e, "status_code", None)
        log.warning("model_error class=%s status=%s", type(e).__name__, status_code)
        return ModelResult("error", "", f"anthropic/{self._model}", error=type(e).__name__)
