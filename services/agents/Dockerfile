# Live Well Agent Service (T-AGT-01), for Cloud Run. Not deployed yet (D-17).
# Build from the repository root so the shared safety rules and the fixed
# fixed texts come along:
#   docker build -f services/agents/Dockerfile -t agents .
# The Anthropic key is never baked in: Cloud Run maps a Secret Manager secret
# to the env var (--set-secrets ANTHROPIC_API_KEY=<secret>:latest).
FROM python:3.12-slim

WORKDIR /srv
COPY services/agents/pyproject.toml services/agents/
COPY services/agents/src services/agents/src
COPY services/agents/prompts config/prompts
COPY packages/safety-rules/rules.json packages/safety-rules/label_rules.json config/safety-rules/
COPY content/coach/moments/morning.json config/morning.json
COPY content/coach/agent/fallbacks.json config/agent_fallbacks.json
RUN pip install --no-cache-dir "./services/agents[firebase]"

ENV AGENTS_ENV=prod \
    AGENTS_MODEL_PROVIDER=anthropic \
    LW_SAFETY_RULES_DIR=/srv/config/safety-rules \
    LW_PROMPTS_DIR=/srv/config/prompts \
    LW_MORNING_MOMENT_PATH=/srv/config/morning.json \
    LW_AGENT_FALLBACKS_PATH=/srv/config/agent_fallbacks.json \
    PORT=8080
USER nobody
CMD exec uvicorn livewell_agents.app:create_app --factory --host 0.0.0.0 --port "$PORT"
