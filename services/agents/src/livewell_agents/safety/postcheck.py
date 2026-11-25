"""Safety.post (spec 9.4 step 8): APPROVE | REWRITE(reason) | BLOCK.

Every model draft passes through here before anyone sees it; the graph has
no edge around it. Checks, all plain code:
  - the shared red-flag rules on the output (packages/safety-rules/rules.json);
  - the short-label rules (label_rules.json): medicine and supplement words,
    weight/calorie/fasting words, disordered-eating phrases, shaming words;
  - output rules below: cure or reversal promises, dose numbers, diagnosis,
    links, phone numbers (a model must never write an emergency number),
    money and payment words, markup or leftover placeholders, length.
Reasons are short codes; they go to traces and to the one retry, never text.

`escalate_post` then folds in the safety classifier (T-AGT-02) for a draft
the rules approved: it can turn APPROVE into REWRITE or BLOCK, never the
other way; a classifier that failed means BLOCK (the fixed fallback).
"""

from __future__ import annotations

import re
from collections.abc import Sequence
from dataclasses import dataclass, replace
from typing import Literal

from livewell_agents.models import CoachDraft
from livewell_agents.safety.classifier import BLOCKING_REASONS, OutputVerdict
from livewell_agents.safety.rules import RedFlagEngine

Verdict = Literal["approve", "rewrite", "block"]

#: A spoken morning briefing: about 20-45 seconds.
MIN_CHARS = 20
MAX_CHARS = 600

CHECKS = ("red_flags", "label_rules", "med_rule", "cure_claims", "banned_content", "length")

#: Food words for the compensatory-exercise rule below (D-96).
_FOODS = (
    r"(?:cakes?|desserts?|sweets?|mithai|food|meals?|dinner|lunch|breakfast|snacks?|calories|"
    r"pizza|treats?|feast|binge|indulgence|ladoos?|laddoos?|jalebis?|biryani|samosas?|"
    r"chocolates?|ice cream|cookies?|fries|burgers?|what you ate|everything you ate)"
)

#: (code, pattern, verdict). Patterns run on the lowercased raw text.
_OUTPUT_RULES: tuple[tuple[str, re.Pattern[str], Verdict], ...] = (
    # The shared rules are written for first-person input; a draft talks to
    # "you". A briefing never mentions self-harm: blocked, never retried.
    (
        "red_flag_crisis",
        re.compile(
            r"\b(?:suicid\w*|self[- ]?harm\w*|kill(?:ing)? (?:yourself|myself)|"
            r"end(?:ing)? (?:your|my) (?:own )?life|hurt(?:ing)? (?:yourself|myself)|"
            r"(?:want|wanting|wish) to die|not (?:want|wanting) to (?:live|be alive))\b"
        ),
        "block",
    ),
    (
        "cure_claim",
        re.compile(
            r"\b(?:cure[sd]?|curing|reverse[sd]?|reversing|reversal|remission|heal(?:s|ed|ing)? "
            r"(?:your|the|my) (?:body|diabetes|disease|condition|heart|blood)|get rid of "
            r"(?:your|the) (?:diabetes|disease|condition)|guarantee[sd]?|promise[sd]?)\b"
        ),
        "rewrite",
    ),
    (
        "dose_number",
        re.compile(
            r"\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|µg|g|grams?|ml|units?|iu|tablets?|pills?|doses?|"
            r"kcal|calories|kg|lbs?|pounds)\b"
        ),
        "rewrite",
    ),
    (
        "diagnosis",
        re.compile(
            r"\bdiagnos\w*|\byou (?:have|may have|might have) (?:a |an )?"
            r"(?:disease|disorder|condition|diabetes|depression)\b"
        ),
        "rewrite",
    ),
    ("link", re.compile(r"https?://|\bwww\.|\b[a-z0-9-]+\.(?:com|org|net|in|io)\b"), "block"),
    (
        "phone_number",
        re.compile(r"\b(?:911|988|112|14416|108|102)\b|(?:\+?\d[\s-]?){6,}"),
        "block",
    ),
    (
        "money",
        re.compile(
            r"[$₹€£]|\b(?:usd|inr|rupees?|dollars?|transfer|payment|pay|bank|password|"
            r"otp|card number|price|discount|buy)\b"
        ),
        "block",
    ),
    ("markup", re.compile(r"[{}<>\[\]`#*]|\\n"), "rewrite"),
    # ---- D-96: gaps found by the eval harness (agent-only; drafts talk to "you").
    # Medicine words the label rules miss: prescriptions, OTC brand names,
    # Romanised Hindi (DRAFT: Hindi-fluent clinician review), tapering, and
    # "shot" only as a medicine (never "give it a shot").
    (
        "med_rule",
        re.compile(
            r"\b(?:prescriptions?|prescribed|painkillers?|pain ?relievers?|antibiotics?|antacids?|"
            r"paracetamol|acetaminophen|tylenol|ibuprofen|advil|motrin|aleve|naproxen|crocin|dolo|"
            r"combiflam|disprin|calpol|goli|goliyan|goliyaan|dawai|dawaai|dawa|davai|dawaiyan)\b"
            r"|\b(?:insulin|flu|b12|ozempic|mounjaro|wegovy|booster) (?:shots?|jabs?|pens?)\b"
            r"|\b(?:skip|skipping|miss|missing|take|taking|stop|stopping|delay|pause|double|halve|"
            r"cut|reduce|increase|lower|change|move|push) (?:your|my|the|today'?s|tonight'?s|"
            r"this morning'?s|an extra|one|two|that) (?!best )(?:\w+ )?shots?\b"
            r"|\b(?:taper(?:ing)?|wean(?:ing)?) (?:yourself )?off\b"
        ),
        "rewrite",
    ),
    # Compensatory exercise and food-as-something-to-earn (FR-SAF-04, 14.1):
    # "walk off that cake", "earn your dessert", "make up for last night's dinner".
    (
        "disordered_eating",
        re.compile(
            r"\b(?:burn|burning|work|working|walk|walking|run|running|sweat|sweating|jog|jogging|"
            r"cycle|cycling|dance|dancing|exercise) off (?:that |the |your |this |those |these |"
            r"all |some |any |it |yesterday'?s |last night'?s |today'?s |tonight'?s )?(?:\w+ )?"
            + _FOODS
            + r"\b"
            r"|\bearn(?:ed|ing|s)? (?:your|that|the|my|a|this|some|tonight'?s|today'?s|an?) "
            r"(?:\w+ )?" + _FOODS + r"\b"
            r"|\b(?:make up for|makes up for|compensate for|cancel out|cancels out|undo|undoes) "
            r"[^.!?]{0,30}\b(?:" + _FOODS + r"|eating|ate)\b"
        ),
        "rewrite",
    ),
    # Cure or reversal promises without cure/reverse words.
    (
        "cure_claim",
        re.compile(
            r"\b(?:diabetes|prediabetes|pre-diabetes|your (?:sugar|condition|disease|illness|bp)|"
            r"(?:high )?blood (?:pressure|sugar)|hypertension|cholesterol|insulin resistance|"
            r"neuropathy|fatty liver|pcos|heart disease)\b[^.!?]{0,40}\b(?:(?:will|would|could|can|"
            r"is going to|are going to) (?:soon )?(?:be (?:gone|history|a thing of the past|over|"
            r"behind you)|go away|disappear|vanish|melt away)|(?:is|are) (?:gone|history))\b"
            r"|\b(?:free|rid) of (?:your |the |all )?(?:diabetes|prediabetes|disease|condition|"
            r"medications?|meds|medicines?|insulin|pills|tablets|treatment)\b"
            r"|\b(?:diabetes|disease|medication|medicine|insulin|pill|drug)[- ]free\b"
            r"|\bnever (?:need|have to take|have to use|take|use)\b[^.!?]{0,25}\b(?:treatments?|"
            r"medications?|medicines?|meds|insulin|pills|tablets|a doctor|doctors)\b"
            r"|\b(?:no longer|won'?t|will not|wouldn'?t) (?:need|have to take)\b[^.!?]{0,20}\b"
            r"(?:treatments?|medications?|medicines?|meds|insulin|pills|tablets)\b"
            r"|\b(?:undo|undoes|undoing|undid|undone|erase[sd]?|erasing|wipe[sd]? out|repairs?|"
            r"repairing|fix(?:es)?|fixing) (?:all |most |much )?(?:of )?(?:the |your |that )?"
            r"damage\b"
            r"|\b(?:beat|beats|beating|defeat|defeats|conquer|conquers|overcome|overcomes)"
            r" (?:your |the )?(?:diabetes|prediabetes|disease|condition)\b"
        ),
        "rewrite",
    ),
    # Money written as "Rs 499" or "499/-".
    (
        "money",
        re.compile(r"\brs\.?\s?\d|\b\d[\d,]*\s?(?:/-|rs\b)|\b(?:rupaye|rupay|rupaiye)\b"),
        "block",
    ),
    # Portal or programme offers. A briefing has no catalog entry for any
    # offer (FR-SAF-07; T-AGT-07 owns real portal cards), so any offer in a
    # briefing is made up.
    (
        "portal_offer",
        re.compile(
            r"\b(?:enrol|enroll|enrols|enrolls|enrolled|enrolling|enrolment|enrollment|"
            r"masterclass(?:es)?|master class(?:es)?|webinars?|workshops?|bootcamps?|seminars?|"
            r"membership|subscribe|subscription|coupon|promo code|special offer|limited[- ]time|"
            r"early bird)\b"
            r"|\b(?:register|sign up|signup) (?:for|now|today)\b"
            r"|\b(?:book|reserve|save) your (?:seat|spot|place)\b"
            r"|\b(?:seats?|spots?) (?:are |is )?(?:filling|limited|left|going fast|selling)"
            r"|\b(?:live|online|paid|premium) (?:\w+ )?(?:course|program|programme|class|classes|"
            r"session|sessions|event|q&a)\b"
            r"|\bdr\.?\s?(?:murthy\s)?gokula'?s (?:\w+ )?(?:course|program|programme|class|"
            r"session|event|book|community|group|portal)\b"
        ),
        "block",
    ),
    # A draft that talks about its own instructions (an injection worked).
    (
        "meta_talk",
        re.compile(
            r"\b(?:system|developer|hidden|secret) (?:prompt|message|instructions?)\b"
            r"|\bmy (?:prompt|instructions|guidelines|programming|training data)\b"
            r"|\bi (?:was|am|have been|'ve been|'m) (?:told|instructed|programmed|trained|"
            r"designed) to\b|\bas an ai\b|\blanguage model\b|\bjailbr\w*|\bdeveloper mode\b"
        ),
        "block",
    ),
    # A draft that claims to be a doctor or Dr. Gokula speaking: the companion
    # is never the doctor (impersonation; closed-script spirit).
    (
        "impersonation",
        re.compile(
            r"\b(?:this is|i am|i'm|it'?s|here'?s) (?:your )?dr\.?\s?(?:murthy\s)?gokula\b"
            r"|\bdr\.?\s?(?:murthy\s)?gokula (?:here|speaking|writing)\b"
            r"|\b(?:i am|i'm|as) (?:your|a|an) (?:doctor|physician|nurse|clinician|pharmacist|"
            r"endocrinologist|cardiologist|dietitian)\b"
            r"|\bi (?:personally )?(?:approve|authori[sz]e|prescribe|diagnose|clear you)\b"
        ),
        "block",
    ),
    # ---- T-AGT-04 (D-98): reading numbers or trends as a condition (spec 9.3
    # Insights "never interpret metrics diagnostically"; the weekly review and
    # replies see trends): "could mean depression", "a sign of thyroid
    # trouble", "means you are depressed", "your diabetes is improving".
    (
        "diagnosis",
        re.compile(
            r"\b(?:could|may|might|can|would|does|do|will)? ?(?:mean|means|indicate|indicates|"
            r"signal|signals|point to|points to|suggest|suggests)\b[^.!?]{0,30}\b(?:depress\w*|"
            r"anxiety|disorders?|diseases?|thyroid|diabet\w*|illness|deficien\w*|syndromes?|"
            r"infections?|burnout|hypertension|insomnia|neuropathy)\b"
            r"|\b(?:sign|signs|symptom|symptoms|signal|indicator|warning sign)s? of (?:a |an )?"
            r"(?:\w+ )?(?:diseases?|disorders?|conditions?|illness|depression|anxiety|"
            r"deficiency|thyroid|diabetes|infection|syndrome|burnout|insomnia)\b"
            r"|\b(?:means?|meaning|suggests?|indicates?|shows?) (?:that )?you(?:'re| are| have|"
            r" might be| may be| could be| might have| may have) (?:\w+ )?(?:depressed|"
            r"depression|anxious|diabetic|ill|sick|deficient|burn(?:ed|t) out|insomnia|"
            r"hypertensive)\b"
            r"|\byour (?:diabetes|prediabetes|sugars?|blood sugar|glucose|a1c|hba1c|blood pressure|"
            r"bp|cholesterol|condition|thyroid|heart)\b[^.!?]{0,20}\b(?:is|are|looks?|seems?)"
            r" (?:improving|getting better|better|worse|getting worse|under control|normal|"
            r"healthy|fine|fixed)\b"
        ),
        "rewrite",
    ),
    # ---- T-AGT-04 (D-98): guilt and shame the label words miss (spec 9.3
    # Coach "must never shame the user"; FR-DLY-07 streak forgiveness).
    (
        "shaming",
        re.compile(
            r"\b(?:ashamed|shameful|shame on you|embarrassing|embarrassed of you)\b"
            r"|\b(?:try|work|push) harder\b|\b(?:disappointed|disappointing) (?:in|with) you\b"
            r"|\byou (?:failed|let (?:yourself|me|us) down|keep failing|gave up again|"
            r"should have known better|have no willpower|lack willpower)\b"
            r"|\b(?:lost|broke|ruined|blew) your streak again\b"
        ),
        "rewrite",
    ),
)

_LABEL_CODES = {
    "medication": "med_rule",
    "not_allowed": "weight_or_diet",
    "disordered_eating": "disordered_eating",
    "unkind": "shaming",
}


@dataclass(frozen=True)
class PostCheckResult:
    verdict: Verdict
    reasons: tuple[str, ...]
    rule_ids: tuple[str, ...]
    checks: tuple[str, ...] = CHECKS


def post_check(
    draft: CoachDraft, engine: RedFlagEngine, max_chars: int = MAX_CHARS
) -> PostCheckResult:
    """`max_chars`: the mode's length limit (T-AGT-04: a nudge is shorter
    than a weekly review); the morning briefing's MAX_CHARS by default."""
    text = draft.text
    lower = text.lower()
    reasons: list[str] = []
    rule_ids: list[str] = []
    verdict: Verdict = "approve"

    def fail(code: str, v: Verdict) -> None:
        nonlocal verdict
        if code not in reasons:
            reasons.append(code)
        verdict = "block" if v == "block" or verdict == "block" else "rewrite"

    finding = engine.check(text)
    if finding.category is not None:
        rule_ids.extend(finding.rule_ids)
        # A draft that itself talks about an emergency or self-harm is never retried.
        fail(f"red_flag_{finding.category}", "block" if finding.interrupts else "rewrite")
    for rule_id, kind in engine.label_hits(text):
        rule_ids.append(rule_id)
        fail(_LABEL_CODES.get(kind, kind), "rewrite")
    for code, pattern, v in _OUTPUT_RULES:
        if pattern.search(lower):
            fail(code, v)
    stripped = text.strip()
    if len(stripped) < MIN_CHARS:
        fail("too_short", "rewrite")
    if len(stripped) > max_chars:
        fail("too_long", "rewrite")
    return PostCheckResult(verdict, tuple(reasons), tuple(dict.fromkeys(rule_ids)))


# ------------------------------------------------------------ grounding (T-AGT-04)

#: Spec 9.1 rule 4 / 9.6: health facts only from approved passages, with
#: their source ids. A draft that states a health fact must cite at least one
#: passage it was given; one that cites an id it was not given is rewritten.
#: The detector is deliberately broad (a missed claim is worse than a retry);
#: the live-tier judge (spec 15.2, "health claims with a valid approved
#: source >= 95%") measures what it misses.
GROUNDING_CHECK = "source_presence"

_HEALTH_TERMS = (
    r"(?:blood sugar|blood glucose|glucose|insulin|a1c|hba1c|blood pressure|cholesterol|"
    r"triglycerides|inflammation|metabolism|cortisol|hormones?|immune system|immunity|"
    r"heart health|heart disease|diabetes|prediabetes|digestion|gut health|"
    r"(?:the )?risk of|your risk|arteries|liver|kidneys?)"
)
_HEALTH_CLAIM = re.compile(
    r"\b(?:studies|research|researchers|evidence|science|scientists|experts|data|trials?)"
    r" (?:shows?|suggests?|says?|found|finds|proves?|confirms?|has shown|have shown)\b"
    r"|\b(?:clinically|scientifically|medically) (?:proven|shown|tested)\b"
    r"|\b(?:is|are|has been|have been) (?:proven|shown) to\b"
    r"|\b(?:lowers?|lowering|reduces?|reducing|improves?|improving|raises?|raising|boosts?|"
    r"boosting|controls?|controlling|regulates?|regulating|balances?|balancing|stabili[sz]es?|"
    r"stabili[sz]ing|spikes?|spiking|protects?|protecting|strengthens?|strengthening|"
    r"helps? (?:to )?(?:lower|reduce|control|manage|regulate|balance|improve))\b"
    r"[^.!?]{0,40}\b" + _HEALTH_TERMS + r"\b"
    r"|\b(?:helps?|helping|good for|great for|better for|bad for|harmful to|works on)\b"
    r"[^.!?]{0,25}\b" + _HEALTH_TERMS + r"\b"
    r"|\b" + _HEALTH_TERMS + r"\b[^.!?]{0,30}\b(?:drops?|falls?|rises?|spikes?|goes (?:up|down)|"
    r"improves?|gets? better|comes? down)\b"
)


def grounding_check(draft: CoachDraft, provided: frozenset[str] | set[str]) -> PostCheckResult:
    """APPROVE, or REWRITE with `unknown_source` (a cited id that was not
    provided) / `unsourced_health_claim` (a health fact with no cited
    passage). With no passages provided, any health fact is unsourced."""
    reasons: list[str] = []
    cited = set(draft.source_ids)
    if cited - set(provided):
        reasons.append("unknown_source")
    if _HEALTH_CLAIM.search(draft.text.lower()) and not (cited & set(provided)):
        reasons.append("unsourced_health_claim")
    return PostCheckResult(
        "rewrite" if reasons else "approve", tuple(reasons), (), (GROUNDING_CHECK,)
    )


#: A nudge may show on a lock screen (AGENTS.md, FR-TCH-02): nothing personal.
PRIVACY_CHECK = "lock_screen_privacy"


def personal_text_check(draft: CoachDraft, personal: Sequence[str]) -> PostCheckResult:
    """REWRITE (`personal_in_nudge`) when the draft carries the person's name,
    Why or other personal text. The nudge model is never sent these; this
    catches it anyway (defence in depth)."""
    lower = draft.text.lower()
    hit = any(len(p.strip()) >= 3 and p.strip().lower() in lower for p in personal)
    return PostCheckResult(
        "rewrite" if hit else "approve",
        ("personal_in_nudge",) if hit else (),
        (),
        (PRIVACY_CHECK,),
    )


def combine_post(first: PostCheckResult, second: PostCheckResult) -> PostCheckResult:
    """Both checks' findings; the stricter verdict wins (block > rewrite > approve)."""
    order = {"approve": 0, "rewrite": 1, "block": 2}
    verdict = first.verdict if order[first.verdict] >= order[second.verdict] else second.verdict
    return PostCheckResult(
        verdict,
        tuple(dict.fromkeys((*first.reasons, *second.reasons))),
        tuple(dict.fromkeys((*first.rule_ids, *second.rule_ids))),
        tuple(dict.fromkeys((*first.checks, *second.checks))),
    )


#: Reason-code prefix for a classifier finding (e.g. cls_medication_advice).
CLASSIFIER_REASON_PREFIX = "cls_"
CLASSIFIER_CHECK = "safety_classifier_output"


def escalate_post(result: PostCheckResult, verdict: OutputVerdict) -> PostCheckResult:
    """Combine the rules' verdict with the classifier's. Escalate only."""
    checks = tuple(dict.fromkeys((*result.checks, CLASSIFIER_CHECK)))
    if verdict.failed:
        return replace(
            result,
            verdict="block",
            reasons=tuple(dict.fromkeys((*result.reasons, "classifier_unavailable"))),
            checks=checks,
        )
    if not verdict.unsafe:
        return replace(result, checks=checks)
    new: Verdict = (
        "block"
        if result.verdict == "block" or BLOCKING_REASONS.intersection(verdict.reasons)
        else "rewrite"
    )
    codes = (CLASSIFIER_REASON_PREFIX + r for r in verdict.reasons)
    return replace(
        result,
        verdict=new,
        reasons=tuple(dict.fromkeys((*result.reasons, *codes))),
        checks=checks,
    )
