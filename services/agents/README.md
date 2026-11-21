# Live Well Agent Service

Python service for the in-app agents (spec 9, 10.2). This first slice is **T-AGT-01** (skeleton: graph, typed state, `ModelClient`, tracing, schema validation) and the **morning-briefing prototype** that finishes T-FND-03 (ADR-002, D-90, D-91).

**HUMAN REVIEW REQUIRED** (AGENTS.md rule 9): safety gates, fixed texts, prompt and post-check word lists. The prompt is `pending` clinical review.

## What happens on `POST /v1/briefings/morning`

```
Firebase ID token + App Check  ->  load context (synthetic fixtures, dev only)
  -> Safety.pre rules (plain code, shared red-flag rules, every free-text field)
       emergency / crisis   -> fixed card, region numbers, NO model call of any kind
  -> safety classifier (only with ai_disclosure consent; T-AGT-02, D-93)
       may only ESCALATE: a red flag the rules missed, or a more urgent one
       fails (error, timeout, refusal, bad JSON, prompt not approved) -> fixed briefing
  -> any red flag           -> fixed card for that category, safety event, no Coach call
     safety event < 72 h    -> fixed morning briefing, no model call
  -> ai_disclosure consent?  no -> 403, no model call
  -> prompt registry (pending prompts only in dev)
  -> LangGraph: assemble_context -> coach_draft -> safety_post -> finalize
                                     (one retry: invalid JSON or REWRITE)  -> fallback
     safety_post = rules, then (if they approve) the output classifier; it can
     only turn APPROVE into REWRITE/BLOCK, and a failed classifier means BLOCK
```

The Done-when of T-AGT-02 ("15.3 critical cases at 100%") is `evals/test_safety_15_3_eval.py`: every 15.3 row, in every region (US, IN, unknown), against every classifier behaviour (clear, a lower category, each failure mode). It runs in CI.

| Path | What |
|---|---|
| `src/livewell_agents/safety/` | `rules.py` (typed port of `packages/safety-rules/check_cases.py`, same `rules.json`/`label_rules.json`), `classifier.py` (LLM safety classifier through `ModelClient`, escalate-only, fail safe), `precheck.py` + `escalate_pre`, `postcheck.py` + `escalate_post`, `templates.py` (fixed texts = the app's ARB strings), `events.py` |
| `src/livewell_agents/graph.py` | The LangGraph flow (core library only; no LangChain/LangSmith) |
| `src/livewell_agents/model_client.py` | `ModelClient` protocol + `FakeModelClient` |
| `src/livewell_agents/anthropic_client.py` | `AnthropicModelClient` (official `anthropic` SDK) |
| `src/livewell_agents/tracing.py` | OpenTelemetry spans with an allow-list of code-like attributes only |
| `prompts/` | Prompt registry (spec 9.6): `registry.json` + versioned files with `review_status` and sha256 |
| `evals/` | Offline safety evals (pytest, FakeModelClient) and the opt-in live eval |
| `fixtures/synthetic_users.json` | Invented users. No real data, no PHI |
| `../../packages/schemas/coach_message.schema.json` | The CoachMessage contract (spec 9.5) |

## Run locally

```bash
cd services/agents
python3 -m venv .venv            # git-ignored
. .venv/bin/activate             # PowerShell: .venv\Scripts\Activate.ps1
pip install -e ".[dev]"

ruff check . && ruff format --check . && mypy && pytest -q
```

Start the service with the fake model (no key, no network):

```bash
cp .env.example .env             # .env is git-ignored
set -a; . ./.env; set +a         # PowerShell: Get-Content .env | % { if ($_ -match '^([^#=]+)=(.*)$') { Set-Item "env:$($matches[1])" $matches[2] } }
uvicorn livewell_agents.app:create_app --factory --port 8081

curl -s -X POST localhost:8081/v1/briefings/morning \
  -H "Authorization: Bearer token-demo-us" -H "X-Firebase-AppCheck: app-check-ok" \
  -H "Content-Type: application/json" -d '{}'
```

Synthetic users: `demo-us`, `demo-in`, `demo-x` (region unknown). Fake tokens work only with `AGENTS_ENV=dev` and `LW_DEV_FAKE_AUTH=1`.

## The real model (owner's step)

1. Create a **dev** Anthropic API key in an organisation with **zero data retention** (D-90).
2. Put it in `services/agents/.env` as `ANTHROPIC_API_KEY=...` (never commit it; `.env` is git-ignored) and set `AGENTS_MODEL_PROVIDER=anthropic`. On Cloud Run use Secret Manager: `--set-secrets ANTHROPIC_API_KEY=anthropic-dev-key:latest`.
3. Optional: `LW_ANTHROPIC_MODEL` (default `claude-opus-5-5`), `LW_ANTHROPIC_EFFORT` (`low` default, `medium`, `high`).
4. Live eval (costs money, synthetic users only, never in CI):

   ```bash
   LW_LIVE_EVALS=1 pytest -m live evals/live -s     # LW_LIVE_RUNS=3 per user by default
   ```

The client uses adaptive thinking, explicit effort, structured output (`output_config.format`) for the draft, checks `stop_reason == "refusal"` before reading content, and turns on the server-side refusal fallback (`fallbacks: "default"`, beta `server-side-fallback-2026-07-01`). Errors become a fallback briefing; only the exception class name is logged.

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `AGENTS_ENV` | `prod` | `dev` / `staging` / `prod`. Only `dev` uses pending prompts and synthetic fixtures |
| `AGENTS_MODEL_PROVIDER` | `fake` | `fake` (dev only) or `anthropic` |
| `ANTHROPIC_API_KEY` | — | Only from env / Secret Manager |
| `LW_ANTHROPIC_MODEL` / `_EFFORT` / `_MAX_TOKENS` / `_TIMEOUT_S` | `claude-opus-5-5` / `low` / `16000` / `60` | Model call |
| `LW_SAFETY_CLASSIFIER_MAX_TOKENS` / `_TIMEOUT_S` | `4000` / `15` | Safety classifier call (same model, effort `low`); a timeout means the fixed text |
| `LW_FIREBASE_PROJECT` | — | Turns on Firebase Admin auth + Firestore consents (`firebase` extra) |
| `LW_REQUIRE_APP_CHECK` | `1` | `0` only for local Firebase testing |
| `LW_DEV_FAKE_AUTH` | — | `1` = fake tokens (dev only) |
| `LW_OTEL_CONSOLE` | — | `1` = print redacted spans |
| `LW_SAFETY_RULES_DIR`, `LW_PROMPTS_DIR`, `LW_MORNING_MOMENT_PATH`, `LW_FIXTURES_PATH` | repo paths | Set in the Dockerfile |

## Logs and traces

Never mood, energy, sleep, stress, health values or any free text (Why, notes, model output). Span attributes pass `tracing.safe_attrs`: an allow-list of keys with numbers, booleans or code-like strings (ids, rule ids, versions, reason codes); a test feeds a distinctive Why and note through a full run and checks no span or log contains them. Safety events carry category, rule ids and field *names* only.

## Adding eval cases

- Context red flags: `evals/cases/briefing_safety_cases.json`; the whole shared set `packages/safety-rules/cases.json` is also run in the Why and check-in note fields.
- Spec 15.3 set: `evals/cases/safety_15_3_cases.json` (`input` red flags, `coach_input` rows, `output` drafts, `classifier_only` red flags the rules miss today; when a rule is added for one, the test asks you to move it). Scripted classifier answers and failure modes: `evals/classifier_fakes.py`.
- Model outputs: `evals/cases/adversarial_outputs.json` (`unsafe` must be rejected and end as the fallback; `safe` must be approved).
- Every miss found in review becomes a case. Critical cases must pass 100%; CI (`.github/workflows/agents.yml`) fails otherwise.
