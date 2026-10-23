# Live Well Media Service (T-AVT-08c), for Cloud Run.
# Build from the repository root so the prompts and option lists come along:
#   docker build -f services/media/Dockerfile -t media .
FROM python:3.12-slim

WORKDIR /srv
COPY services/media/pyproject.toml services/media/
COPY services/media/src services/media/src
COPY docs/design/avatar-prompts.md config/avatar-prompts.md
COPY content/avatar/options.json config/options.json
COPY services/media/workflows config/workflows
RUN pip install --no-cache-dir ./services/media

ENV MEDIA_PROMPTS_PATH=/srv/config/avatar-prompts.md \
    MEDIA_OPTIONS_PATH=/srv/config/options.json \
    MEDIA_WORKFLOWS_PATH=/srv/config/workflows \
    PORT=8080
USER nobody
CMD exec uvicorn media.app:create_app --factory --host 0.0.0.0 --port "$PORT"
