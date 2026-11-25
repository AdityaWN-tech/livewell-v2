"""Live Well Agent Service (spec 9, 10.2): T-AGT-01 skeleton and the
T-FND-03 morning-briefing spike (ADR-002, D-90)."""

import os as _os

# langgraph depends on langchain-core, which ships the LangSmith client. We
# never use LangSmith (D-90: traces stay in our own GCP project); force its
# tracing off so no environment variable can turn it on by accident.
for _var in ("LANGSMITH_TRACING", "LANGCHAIN_TRACING_V2", "LANGCHAIN_TRACING"):
    _os.environ[_var] = "false"
