# ADR-002: Agent Service framework: LangGraph or Google ADK (T-FND-03, framework part)

| | |
|---|---|
| Status | **Proposed, needs owner decision.** Nothing is built. AGENTS.md's stack table stays "LangGraph or Google ADK" until the owner decides (D-90). |
| Date | 2026-11-19 |
| Task | T-FND-03 (vendor and framework spike: "agent framework (LangGraph vs ADK) ... Write ADRs"). Done when (spec 17.4): "ADRs merged with scorecards against the Section 8.3 criteria; morning-briefing prototype runs end to end". This ADR is the paper half; the spike (below) is the other half. |
| Related | D-03 (India + US, region-aware safety), D-14 (nam5; Cloud Run may run in a US and an India region), D-17 (Spark plan, nothing deployed yet), D-21/D-22 (safety engine, event logging), D-80 (T-FND-10 left agent tracing open), D-90; ADR-001; ADR-003 |

## Context

The Agent Service (spec 10.2) is a Python service on Cloud Run that runs the orchestrator and the agents of spec 9.3. AGENTS.md fixes the language and tooling (Python, ruff, mypy, pydantic I/O, Cloud Run, Terraform, GitHub Actions) and leaves only the framework open. `services/agents/` is still empty (`prompts/`, `evals/` placeholders). What already exists and must be reused, not duplicated:

- `packages/safety-rules/`: the shared red-flag rules (`rules.json`, `label_rules.json`) with a **Python reference engine** and 69 critical cases, already gated in CI (`safety-rules.yml`). Safety.pre in the agent service should call this engine as plain code.
- `services/media/`: the house style for a Python Cloud Run service (FastAPI, pydantic 2, uvicorn, httpx; ruff with security rules; `mypy --strict`; Firebase ID token + App Check + server-side consent checks in `auth.py`). The agent service should copy this shape.
- `services/core-api/`: TypeScript Cloud Functions (Node 22) for consents, audit log and deletions.

### Requirements drawn from the spec

| # | Requirement | Spec |
|---|---|---|
| R1 | **Deterministic rules first, AI second.** Emergency/crisis detection, frequency caps, consent checks and voice routing are ordinary code that runs **before any AI** and cannot be "talked out of" their behaviour. EMERGENCY/CRISIS returns a fixed template with no LLM call, neutral voice, region-aware numbers (IN 112 / 14416, US 911 / 988). | 9.1 (1), 9.4 step 3, FR-VOC-07, D-03, AGENTS.md |
| R2 | Orchestrator-worker graph with typed state, tool calling, retries, human-in-the-loop steps and tracing; the request flow is a fixed sequence: pre-check, intent, retrieve, respond, portal, post-check (APPROVE / REWRITE once / BLOCK), persist. | 9.2, 9.4 |
| R3 | Narrow agents with **fixed JSON input/output schemas** and an explicit tool allow-list; the Coach returns `CoachMessage` (9.5); "invalid JSON is retried"; schema validity 99.5% or more. | 9.1 (2), 9.5, 15.2, T-AGT-01 |
| R4 | Agents **propose**; users or code decide (memory, plan changes). | 9.1 (3), T-AGT-05 |
| R5 | Approved knowledge only: RAG over the approved content index; unapproved item not retrievable. | 9.1 (4), T-AGT-03 |
| R6 | Every run traced: inputs redacted, tools called, output, latency, cost, model and prompt version; full traces kept 30 days in restricted storage; no PHI or free text in logs. | 9.1 (5), NFR-10, T-FND-10, AGENTS.md |
| R7 | LLM behind a `ModelClient` interface: switch models, A/B test, cheap model for tagging, strong one for conversation. LLM vendor not chosen yet (8.3: Claude, Gemini or OpenAI via an enterprise API, zero retention, future BAA). | 9.2, 8.3 |
| R8 | Evaluation harness: pytest + LLM-as-judge + human sample, at least 300 golden cases, CI blocks merge on a critical failure; 15.3 safety set at 100%. | 15.1, 15.2, 15.3, T-AGT-08 |
| R9 | Scheduled jobs (nightly plan, briefing, weekly review, memory follow-up) via Pub/Sub + Cloud Tasks, sharded by time zone; 100k MAU without architectural change; graceful degradation if the agent service is down. | 9.7, 10.1, NFR-03/04/12 |
| R10 | Voice latency: end of speech to first audio 1.5 s p50 / 3.0 s p95 on 4G, so the framework must stream and add little overhead. | NFR-02 |
| R11 | Closed-script rule: the orchestrator issues the `message_id` only after Safety.post; TTS is refused for anything else. | FR-VOC-05, 9.4 step 10, T-VOC-07 |
| R12 | Data stays in our Google Cloud projects where possible; vendors chosen with BAA availability in mind; markets India and US. | 10.3, 16.1, D-03, D-14 |
| R13 | Prompt registry: versioned prompt files in the repo plus a Remote Config pointer; changes pass review and the eval suite. | 9.6, T-AGT-04 |

## Options

Facts checked on 2026-11-19 from the official repositories, package registries and docs (Sources at the end).

| | **A. LangGraph** (core library only) | **B. Google ADK (Python)** |
|---|---|---|
| What it is | "A low-level orchestration framework and runtime for long-running, stateful agents"; graphs of shared state, nodes and edges; "does not require LangChain". | Google's open-source agent framework; "optimized for Gemini, ADK is model-agnostic, deployment-agnostic". 2.0 added a graph-based Workflow runtime that "weave[s] deterministic code with adaptive AI reasoning". |
| Version, licence | `langgraph` 1.2.23 (19 Nov 2026), PyPI status "Production/Stable", MIT. | `google-adk` 2.14.1 (12 Nov 2026), Apache-2.0. Python 2.0.0 shipped 19 May 2026; the 1.x line was still released until v1.39.0 (17 Aug 2026). |
| Maturity signal | 1.x stable line; ~45k GitHub stars; LangChain Inc. backs it. | Fast-moving: 2.0 → 2.14 in six months; ~22k stars; Google backs it; also in TypeScript, Go, Java, Kotlin. |

### Comparison

Scores: ●●● strong fit, ●● workable, ● weak. "Neutral" means our own code does the job whatever the framework.

| Criterion (requirement) | A. LangGraph | B. Google ADK |
|---|---|---|
| **Deterministic safety-first routing** (R1, R2, R11) | ●●● Nodes are plain Python functions and edges are explicit, so spec 9.4 maps one to one: `safety_pre` → conditional edge → `fixed_template` (no LLM) or `intent` → ... → `safety_post` → `persist`. In both options Safety.pre runs **outside** the framework too (FastAPI handler calls the `packages/safety-rules` engine first), so a framework bug cannot skip it. | ●● Graph Workflow (2.0) can express the same flow; callbacks (`before_model`, plugins) can block calls. The agent-first model (an `LlmAgent` decides, deterministic steps around it) is easier to get subtly wrong; graph workflows are only six months old in Python. |
| **Structured pydantic I/O** (R3) | ●●● State can be a pydantic model or TypedDict; we validate `CoachMessage` ourselves in the node and retry once. Structured output comes from our `ModelClient`, not the framework. | ●● `LlmAgent` takes a pydantic output schema; Gemini's native schema mode helps. Through LiteLLM/other connectors the guarantees depend on the provider. |
| **Eval tooling** (R8) | ●● No built-in harness in the core library. LangSmith evals are a paid SaaS (not recommended, see tracing). The spec's harness (pytest + LLM judge + human sample) is ours either way; `services/agents/evals` and the existing `check_cases.py` style fit it. | ●●● `adk eval`, `*.evalset.json`, pytest via `AgentEvaluator`, criteria for tool trajectory, groundedness (`hallucinations_v1`) and `safety_v1`, and `adk conformance test` for CI. **But** the LLM-judged criteria "need the Vertex Gen AI Evaluation Service" (Google billing, Blaze, D-17), and the 15.3 gate still needs our own deterministic checks. |
| **Tracing for T-FND-10** (R6, NFR-10) | ●● Default path is LangSmith (SaaS, US or EU, 14-day base retention, self-hosting only on Enterprise): **not proposed**, because traces would hold user text outside our projects. Instead: our own OpenTelemetry spans around every node and `ModelClient` call, redacted before export, sent to **Cloud Trace** in our project (or self-hosted Langfuse, which accepts OTLP at `/api/public/otel`, MIT core). More of our own code. | ●●● Emits OpenTelemetry GenAI semantic-convention spans natively; `--otel_to_cloud` / `get_gcp_exporters` send them to Cloud Trace in our project. We still must verify that message content is kept out of spans (the docs show an explicit content-capture flag only for Kotlin) and add our redaction. |
| **Cloud Run deployment** (R9, R10) | ●●● A plain Python library inside our FastAPI container, same Dockerfile shape as `services/media`. We do **not** need LangSmith Agent Server. Checkpointing to Firestore/Postgres only if a flow needs to pause (memory approval is already a Firestore status, `memory_facts.status` in `docs/data-model.md`). | ●●● `adk deploy cloud_run`, or our own FastAPI container; Agent Runtime and GKE also offered. Session/memory services default to Google-managed stores; we would use our own Firestore state. |
| **Model / provider flexibility** (R7) | ●●● Provider-neutral; we write the `ModelClient` (Claude, Gemini or OpenAI SDKs directly). No LangChain needed. | ●● Gemini first-class; others via model connectors (LiteLLM, Apigee, Ollama, vLLM) or Claude hosted on Google's platform; model routing with failover is built in. |
| **Vendor lock-in** | ●●● MIT library; the lock-in risk is the paid LangSmith ecosystem, which we avoid. Graph code is small and portable. | ●● Apache-2.0 and runnable anywhere, but eval judges, tracing defaults, Agent Runtime and Gemini features pull toward Google Cloud. Acceptable, since we are already on Firebase/GCP (D-14). |
| **Team skills** (Flutter + TypeScript + Python) | ●● New concepts (StateGraph, reducers), but it is plain Python, close to what `services/media` already does. | ●● New concepts (agents, sessions, runners, workflows, plugins); larger surface. ADK also exists in TypeScript (2.0 GA), which matters only if the owner later wants agents in TS (not the fixed stack). |
| **Firebase auth** | Neutral: FastAPI middleware verifies Firebase ID token + App Check, as `services/media/auth.py` does. | Neutral: same. ADK's "built-in authentication" on Google Cloud deployments is not needed. |
| **Accessibility** | Not applicable (server). | Not applicable. |
| **Hosting / cost** | Free library; Cloud Run + Cloud Trace usage only. LangSmith would be $39/seat/month (Plus) plus traces: not needed. | Free library; Cloud Run + Cloud Trace. LLM-judged evals bill Vertex AI per run. |
| **Maturity** | ●●● 1.x, Production/Stable, frequent patch releases. | ●● Production-grade backing, but the 2.x graph API is new and changes quickly (14 minor releases in six months). |
| **India + US, data residency** (R12) | Neutral: run Cloud Run in `us-central1`/`us-east1` and, if latency needs it, an India region (D-14); traces stay in our project. | Neutral, same; Vertex/Gemini regional endpoints are a plus if Gemini is the LLM. |

### Other options the owner should know about (out of scope for this decision)

| Option | Why out of scope |
|---|---|
| **Pydantic AI** (MIT, 2.71, Production/Stable; pydantic-graph, pydantic_evals, OTel) | The best fit for "pydantic I/O" on paper and model-neutral, but the spec (9.2, 10.2) and AGENTS.md name only LangGraph or ADK; adding it would be a stack change. Worth a look only if both candidates fail the spike. |
| **No framework** (FastAPI + our own state machine + `ModelClient`) | Spec 9.4 is short and mostly deterministic, so this is feasible and the most transparent. Out of scope because the spec asks for a framework with typed state, retries and HITL; it stays the fallback if the spike shows either framework gets in the way. |
| OpenAI Agents SDK (MIT, 0.25), CrewAI (MIT) | Built around autonomous agent hand-offs or role-playing crews; weaker fit for a fixed, safety-gated pipeline; OpenAI SDK leans to one provider. |
| Microsoft AutoGen | Archived; Microsoft says "we continue to advise against production use" and points to Microsoft Agent Framework (Azure-first, outside our GCP stack). |
| LangChain (agents), LangSmith, LangSmith Agent Server | Not needed with LangGraph; they add dependencies, a paid SaaS and traces outside our projects. |

## Recommendation

**A. LangGraph, core library only, on our own FastAPI service on Cloud Run, with our own `ModelClient`, our own pytest eval harness, and OpenTelemetry traces exported (redacted) to Cloud Trace in our GCP project. No LangChain, no LangSmith.**

Top reasons:
1. **Safety-first fits naturally.** Spec 9.4 is a fixed graph with two hard gates; LangGraph's explicit nodes and conditional edges express it directly, and the safety pre-check also runs before the graph is even invoked (`packages/safety-rules` engine), so the "rules first" guarantee does not depend on any framework.
2. **Provider-neutral while the LLM is still unchosen.** Spec 9.2 wants a `ModelClient` we can switch; the LLM vendor (8.3) is open and must offer zero retention and a future BAA. LangGraph does not care which model we call; ADK is "optimized for Gemini".
3. **Stable and small.** MIT, 1.x Production/Stable; we use only the graph runtime. ADK's Python graph API is six months old and moving fast, which is a risk for safety code that clinical reviewers sign off.

What we give up versus ADK: built-in OTel spans and the built-in eval runner. Both are covered by our own code that the spec needs anyway (redaction for NFR-10; deterministic 15.3 gate for T-AGT-08).

### What would change the recommendation

- **The owner chooses Gemini on Vertex AI as the LLM** (BAA under the Google Cloud agreement, regional endpoints, one bill): ADK becomes the stronger choice (native Gemini schema mode, native Cloud Trace spans, Vertex evaluation).
- **The spike** (below) shows ADK's graph Workflow expresses spec 9.4 as clearly, with equal or lower latency, and its OTel spans can be made content-free.
- LangGraph's licence or governance changes (for example, core features moving behind LangSmith), or a release breaks the 1.x API.
- The owner wants managed agent hosting (Agent Runtime) instead of our own Cloud Run service.

## Risks

| Risk | Mitigation |
|---|---|
| A framework path bypasses a safety gate. | Safety.pre runs in the HTTP handler before the graph; Safety.post is a mandatory node with no edge around it; a unit test walks every edge; the 15.3 set runs in CI (T-AGT-08). |
| PHI leaks into traces. | Redact before span export (field allow-list, no free text); traces only to our project; 30-day retention on a restricted bucket (NFR-10). A test asserts no raw user text in exported spans (T-FND-10). |
| Framework churn. | Pin exact versions; keep agent logic in plain functions with pydantic I/O so the graph layer is thin and replaceable. |
| More own code (tracing, evals). | Small and needed anyway; the existing `check_cases.py` pattern is the template. |
| Nothing deployable until Blaze (D-17). | The spike and T-AGT-01 run locally against the Firebase emulators and a dev LLM key; deploy when Blaze is on. |

## Spike to finish T-FND-03 (spec 9.2: "a 1-week spike that builds the morning-briefing flow in both candidates")

Build spec 9.7's briefing generator for one fixture user in both frameworks, behind the same `ModelClient` and the same pydantic `CoachMessage`: load context → Safety.pre (`packages/safety-rules`) → retrieve from a 10-passage fixture index (approved only) → Coach → Safety.post → `message_id`. Score: (1) 15.3 critical cases routed with zero LLM calls on EMERGENCY/CRISIS, (2) schema validity over 50 runs, (3) p50/p95 overhead added by the framework, (4) spans exported to Cloud Trace (or a local OTel collector) with no user text, (5) lines of glue code, (6) a second model swapped in with one config change. Needs a dev LLM key with zero retention (owner). Record results here and flip Status.

## Owner decisions needed

1. Choose the framework: **LangGraph (recommended)** or ADK.
2. Choose the LLM vendor (spec 8.3) or at least the spike's dev key; if it is Gemini on Vertex, revisit point 1.
3. Approve self-hosting traces in our GCP project (Cloud Trace now; self-hosted Langfuse later if a richer UI is wanted) instead of LangSmith.
4. Approve the 1-week spike (and a small LLM budget) to finish T-FND-03's "prototype runs end to end".
5. Later, with Blaze: which Cloud Run regions (US only, or US + India for latency, D-14).

## Sources (checked 2026-11-19)

- LangGraph repo and releases (MIT, 1.2.23): https://github.com/langchain-ai/langgraph, https://github.com/langchain-ai/langgraph/releases ; PyPI: https://pypi.org/project/langgraph/
- LangGraph overview ("does not require LangChain"): https://docs.langchain.com/oss/python/langgraph/overview
- LangSmith observability and pricing (US/EU cloud, 14-day base retention, self-host on Enterprise, Plus $39/seat): https://docs.langchain.com/langsmith/observability , https://www.langchain.com/pricing
- Google ADK Python repo and releases (Apache-2.0, 2.14.1; 2.0.0 on 2026-05-19): https://github.com/google/adk-python , https://github.com/google/adk-python/releases ; PyPI: https://pypi.org/project/google-adk/
- ADK docs (languages, graph workflows, deploy): https://adk.dev/ ; models: https://adk.dev/agents/models/ ; traces (OTel GenAI conventions, Cloud Trace): https://adk.dev/observability/traces/ ; evaluation (Vertex Gen AI Evaluation Service for LLM criteria): https://adk.dev/evaluate/ ; release notes: https://adk.dev/release-notes/
- Langfuse (MIT core outside `ee/`, OTLP endpoint, self-hosting): https://github.com/langfuse/langfuse , https://langfuse.com/integrations/native/opentelemetry , https://langfuse.com/self-hosting
- Pydantic AI (MIT, 2.71): https://github.com/pydantic/pydantic-ai ; OpenAI Agents SDK: https://github.com/openai/openai-agents-python ; CrewAI: https://github.com/crewAIInc/crewAI ; AutoGen (archived): https://github.com/microsoft/autogen
