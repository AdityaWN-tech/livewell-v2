"""Evaluation harness for the Agent Service (T-AGT-08, spec 15.1-15.3, D-95).

    python -m evals.harness                       # offline tier, as in CI
    python -m evals.harness --json eval-summary.json --markdown eval-summary.md

See services/agents/README.md ("Eval harness") for the case format and how to add cases or targets.
"""

from evals.harness.cases import GoldenCase, GoldenSet, load_golden_set
from evals.harness.runner import CaseResult, run_and_summarise, run_golden_set
from evals.harness.targets import TARGETS, Env, Observation, target

__all__ = [
    "TARGETS",
    "CaseResult",
    "Env",
    "GoldenCase",
    "GoldenSet",
    "Observation",
    "load_golden_set",
    "run_and_summarise",
    "run_golden_set",
    "target",
]
