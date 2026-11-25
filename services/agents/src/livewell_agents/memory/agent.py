"""The Memory Agent: propose, approve and delete (spec 9.3, 9.8; FR-CNV-05;
T-AGT-05).

    propose   after a conversation turn or a reflection: the model suggests
              up to 3 short facts; code keeps only safe ones as `proposed`
    approve   the person saves a proposal (`saved`); only saved facts are used
    delete    the person deletes a fact: text scrubbed, status `deleted`
              (final); its key stays so it is never proposed or used again
    for_coach the saved facts the Coach may see in reply and reflection modes

Order in `propose` (deterministic rules first, AI second, 9.1):
  1. `memory` consent off -> nothing (no model call, nothing stored).
  2. `ai_disclosure` off -> nothing (the text may not reach a model).
  3. Safety.pre rules over the text: any red flag -> nothing is remembered
     (the Coach turn that carried the same text already routed it).
  4. A safety event in the last 72 h -> nothing (as the Coach, D-98a).
  5. Instruction-like text -> nothing.
  6. The input classifier (escalate only): any category or a failure -> nothing.
  7. Prompt `memory_extract` (pending only in dev) -> else nothing.
  8. Model -> MemoryDraft; refusal, error or invalid JSON -> nothing.
  9. Each candidate: policy.check_fact; sensitive without `memory_sensitive`
     -> dropped, never stored; same key as any existing fact (deleted ones
     included) -> dropped; at most MAX_PENDING open proposals.
Logs and spans: ids, codes and counts only, never the text or a fact.
"""

from __future__ import annotations

import json
import logging
import uuid
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from pydantic import ValidationError

from livewell_agents.memory.models import (
    MAX_DRAFT_FACTS,
    MEMORY_DRAFT_JSON_SCHEMA,
    MemoryDraft,
    MemoryFact,
    MemoryFactView,
    MemoryListResponse,
    MemoryProposeRequest,
    MemoryProposeResponse,
)
from livewell_agents.memory.policy import check_fact, fact_key
from livewell_agents.memory.store import FactNotFound, MemoryStore
from livewell_agents.model_client import ModelClient, ModelRequest
from livewell_agents.models import UserContext
from livewell_agents.prompts import PromptRegistry, tag_safe_json
from livewell_agents.safety.classifier import SafetyClassifier
from livewell_agents.safety.precheck import RECENT_EVENT_WINDOW, instruction_like
from livewell_agents.safety.rules import RedFlagEngine
from livewell_agents.tracing import set_attrs, span

log = logging.getLogger("livewell_agents.memory")

PROMPT_ID = "memory_extract"
#: Consent types (the app's ConsentType keys; D-100).
MEMORY_CONSENT = "memory"
MEMORY_SENSITIVE_CONSENT = "memory_sensitive"
#: Open proposals a person can have; beyond this nothing new is proposed
#: until they save or delete some (no endless pile of suggestions).
MAX_PENDING = 20
#: Saved facts the Coach may see in one run (newest first).
MAX_FACTS_FOR_COACH = 20
SOURCE_FIELD = "memory.source_text"


class MemoryConsentRequired(PermissionError):
    pass


class FactClosed(ValueError):
    """The fact was deleted; a deleted fact can never be saved again."""


@dataclass(frozen=True)
class MemoryConsents:
    memory: bool
    sensitive: bool
    ai: bool


class MemoryAgent:
    def __init__(
        self,
        *,
        store: MemoryStore,
        engine: RedFlagEngine,
        model: ModelClient,
        prompts: PromptRegistry,
        classifier: SafetyClassifier,
        allow_pending_prompts: bool,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._store = store
        self._engine = engine
        self._model = model
        self._prompts = prompts
        self._classifier = classifier
        self._allow_pending = allow_pending_prompts
        self._clock = clock

    # ------------------------------------------------------------ propose

    def propose(
        self, ctx: UserContext, request: MemoryProposeRequest, consents: MemoryConsents
    ) -> MemoryProposeResponse:
        with span("memory.propose", {"lw.uid": ctx.uid, "lw.source": request.source}) as s:
            result, dropped = self._propose(ctx, request, consents)
            set_attrs(
                s,
                {
                    "lw.decision": result.status,
                    "lw.reason": result.reason,
                    "lw.proposed": len(result.facts),
                    "lw.dropped": sorted(dropped.elements()),
                },
            )
        log.info(
            "memory.propose status=%s reason=%s proposed=%d dropped=%s",
            result.status,
            result.reason,
            len(result.facts),
            ",".join(sorted(dropped.elements())),
        )
        return result

    def _propose(
        self, ctx: UserContext, request: MemoryProposeRequest, consents: MemoryConsents
    ) -> tuple[MemoryProposeResponse, Counter[str]]:
        dropped: Counter[str] = Counter()

        def skip(reason: str) -> tuple[MemoryProposeResponse, Counter[str]]:
            return MemoryProposeResponse(status="skipped", reason=reason), dropped

        if not consents.memory:
            return skip("memory_off")
        if not consents.ai:
            return skip("no_ai_consent")
        text = request.text
        if self._engine.check(text).category is not None:
            return skip("red_flag")
        now = self._clock()
        if (
            ctx.last_safety_event_at is not None
            and now - ctx.last_safety_event_at < RECENT_EVENT_WINDOW
        ):
            return skip("recent_safety_event")
        if instruction_like(text):
            return skip("instruction_like")
        verdict = self._classifier.classify_input({SOURCE_FIELD: text})
        if verdict.failed:
            return skip("classifier_unavailable")
        if verdict.category is not None:
            return skip("red_flag_classifier")
        prompt = self._prompts.active(PROMPT_ID, allow_pending=self._allow_pending)
        if prompt is None:
            return skip("prompt_not_approved")
        existing = self._store.list(ctx.uid)
        known_keys = {f.fact_key for f in existing}
        pending = sum(1 for f in existing if f.status == "proposed")
        if pending >= MAX_PENDING:
            return skip("too_many_pending")
        draft = self._draft(prompt.text, request)
        if draft is None:
            return skip("model_failed")
        kept: list[MemoryFact] = []
        for candidate in draft.facts[:MAX_DRAFT_FACTS]:
            decision = check_fact(candidate, self._engine)
            if not decision.keep:
                dropped[decision.reason] += 1
                continue
            if decision.sensitive and not consents.sensitive:
                dropped["sensitive_not_opted_in"] += 1
                continue
            key = fact_key(ctx.uid, decision.fact)
            if key in known_keys:
                dropped["already_known"] += 1
                continue
            if pending + len(kept) >= MAX_PENDING:
                dropped["too_many_pending"] += 1
                continue
            known_keys.add(key)
            fact = MemoryFact(
                fact_id=uuid.uuid4().hex,
                fact=decision.fact,
                category=decision.category,
                sensitive=decision.sensitive,
                confidence=candidate.confidence,
                source=request.source,
                source_message_id=request.source_message_id,
                status="proposed",
                fact_key=key,
                prompt_version=prompt.tag,
                created_at=now,
                updated_at=now,
            )
            self._store.add(ctx.uid, fact)
            kept.append(fact)
        if not kept:
            return MemoryProposeResponse(status="nothing", reason="no_fact_kept"), dropped
        return (
            MemoryProposeResponse(
                status="proposed", reason="ok", facts=[MemoryFactView.of(f) for f in kept]
            ),
            dropped,
        )

    def _draft(self, system: str, request: MemoryProposeRequest) -> MemoryDraft | None:
        user = (
            "Find facts worth remembering about this person, if any.\n"
            f"<source>\n{tag_safe_json({'kind': request.source, 'text': request.text})}\n</source>"
        )
        with span("memory.model", {"lw.node": PROMPT_ID}) as s:
            result = self._model.generate(
                ModelRequest(PROMPT_ID, system, user, MEMORY_DRAFT_JSON_SCHEMA)
            )
            set_attrs(s, {"lw.model.status": result.status, "lw.model": result.model})
        if result.status != "ok":
            return None
        try:
            return MemoryDraft.model_validate(json.loads(result.text))
        except (ValueError, ValidationError):
            return None

    # ------------------------------------------------------------ the person's list

    def list(self, uid: str, consents: MemoryConsents) -> MemoryListResponse:
        facts = sorted(
            (f for f in self._store.list(uid) if f.status != "deleted"),
            key=lambda f: f.created_at,
            reverse=True,
        )
        return MemoryListResponse(
            facts=[MemoryFactView.of(f) for f in facts],
            memory_on=consents.memory,
            sensitive_on=consents.sensitive,
        )

    def approve(self, uid: str, fact_id: str, consents: MemoryConsents) -> MemoryFactView:
        fact = self._find(uid, fact_id)
        if fact.status == "deleted":
            raise FactClosed(fact_id)
        if not consents.memory:
            raise MemoryConsentRequired(MEMORY_CONSENT)
        if fact.sensitive and not consents.sensitive:
            raise MemoryConsentRequired(MEMORY_SENSITIVE_CONSENT)
        if fact.status == "saved":
            return MemoryFactView.of(fact)
        saved = self._store.set_status(uid, fact_id, "saved", self._clock())
        log.info("memory.approve fact_id=%s category=%s", fact_id, fact.category)
        return MemoryFactView.of(saved)

    def delete(self, uid: str, fact_id: str) -> None:
        """Always allowed (a user right), whatever the consents. Idempotent."""
        fact = self._find(uid, fact_id)
        if fact.status != "deleted":
            self._store.set_status(uid, fact_id, "deleted", self._clock())
        log.info("memory.delete fact_id=%s", fact_id)

    def delete_all(self, uid: str) -> int:
        now = self._clock()
        count = 0
        for f in self._store.list(uid):
            if f.status != "deleted":
                self._store.set_status(uid, f.fact_id, "deleted", now)
                count += 1
        log.info("memory.delete_all count=%d", count)
        return count

    def _find(self, uid: str, fact_id: str) -> MemoryFact:
        for f in self._store.list(uid):
            if f.fact_id == fact_id:
                return f
        raise FactNotFound(fact_id)

    # ------------------------------------------------------------ the Coach

    def for_coach(self, uid: str, consents: MemoryConsents) -> tuple[str, ...]:
        """Saved facts only, newest first. Memory off -> none. Sensitive ones
        only while `memory_sensitive` is still granted. Proposed and deleted
        facts are never used (FR-CNV-05)."""
        if not consents.memory:
            return ()
        saved = sorted(
            (
                f
                for f in self._store.list(uid)
                if f.status == "saved" and f.fact and (consents.sensitive or not f.sensitive)
            ),
            key=lambda f: f.updated_at,
            reverse=True,
        )
        return tuple(f.fact for f in saved[:MAX_FACTS_FOR_COACH])
