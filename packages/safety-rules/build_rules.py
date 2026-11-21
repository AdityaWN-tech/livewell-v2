import json
import sys

out = sys.argv[1]

MEDS = (r"(?:medicines?|medications?|meds|pills?|tablets?|doses?|dosage|insulin|metformin|glipizide|glimepiride|gliclazide|"
        r"sitagliptin|januvia|semaglutide|ozempic|wegovy|rybelsus|tirzepatide|mounjaro|jardiance|empagliflozin|dapagliflozin|"
        r"farxiga|statins?|atorvastatin|rosuvastatin|lipitor|crestor|lisinopril|amlodipine|losartan|telmisartan|metoprolol|"
        r"warfarin|aspirin|blood thinners?|thyroxine|levothyroxine|thyronorm|antidepressants?|sertraline|prednisone|bp pills?|"
        r"prescriptions?|injections?|painkillers?|paracetamol|acetaminophen|tylenol|ibuprofen|advil|motrin|crocin|dolo|"
        # Romanised Hindi (D-96; DRAFT: needs a Hindi-fluent clinician): goli = pill, dawai/dawa = medicine.
        r"goli|goliyan|goliyaan|dawai|dawaai|dawa|dava|davai|dawaiyan)")
CHANGE = (r"(?:stop|stopping|quit|quitting|skip|skipping|halve|double|increase|decrease|lower|lowering|reduce|reducing|cut down|"
          r"cut back|come off|coming off|get off|getting off|taper|tapering|less|more|swap|replace|instead of|"
          # D-96: halving, and dosing-schedule changes ("every other week instead").
          r"halving|halved|in half|every other|alternate days|alternate weeks|(?:once|twice) a (?:week|month) instead|"
          # D-96: past tense and -ing forms of the same verbs ("I stopped my insulin").
          r"stopped|quits|skipped|skips|halves|doubled|doubling|increased|increasing|decreased|decreasing|"
          r"lowered|reduced|cutting down|cutting back|came off|got off|tapered|swapped|swapping|replaced|replacing)")
#: Romanised Hindi change words (D-96; DRAFT: needs a Hindi-fluent clinician): band (kar) = stop,
#: chhod/chod = quit, mat lo/lena = don't take, kam = less, aadhi = half, zyada = more.
HI_CHANGE = (r"(?:band (?:kar|karo|karna|karni|karke|kardo|kardi|kardiya|ho|kiya|ki|kiye)\w*|chhod\w*|chod\w*|chhor\w*|"
             r"mat (?:lo|lena|lun|loon|khao|khana)|na (?:lo|lena|khao|khana)|kam (?:kar|lo|lena|khao)\w*|"
             r"(?:aadhi|adhi|aadha|adha|zyada|jyada|double) (?:kar|lo|lena|le|khao|goli|dose|tablet)\w*)")
SUPPS = r"(?:supplements?|vitamins?|magnesium|berberine|fish oil|omega 3|turmeric|curcumin|zinc|ashwagandha|chromium|cinnamon pills?)"
NT = r"(?:n ?'?t|not)"  # can't / cant / can not / cannot

rules = {
    "version": "0.1-draft",
    "status": "DRAFT: needs review by the Clinical Content and Safety Committee before launch",
    "matching": (
        "Text is lowercased, curly quotes straightened, characters other than a-z, 0-9, "
        "apostrophe and space become spaces, spaces collapsed. Patterns are regular "
        "expressions searched in that text. The highest-priority matching category wins; "
        "every matching rule id is logged."
    ),
    "categories": [
        {"id": "emergency", "priority": 1, "interrupts": True},
        {"id": "crisis", "priority": 2, "interrupts": True},
        {"id": "disordered_eating", "priority": 3, "interrupts": False},
        {"id": "medication", "priority": 4, "interrupts": False},
        {"id": "pregnancy_complex", "priority": 5, "interrupts": False},
    ],
    "contacts": {
        "US": {"emergency": "911", "crisis_call": "988", "crisis_text": "988",
               "crisis_name": "988 Suicide & Crisis Lifeline"},
        "IN": {"emergency": "112", "crisis_call": "14416", "crisis_text": None,
               "crisis_name": "Tele-MANAS"},
    },
    "rules": [
        {"id": "EM-CHEST", "category": "emergency", "spec": "FR-SAF-01", "patterns": [
            r"\bchest (?:pain|pains|pressure|tightness|is tight|feels tight|hurts|is hurting|squeezing|crushing)\b",
            r"\b(?:crushing|squeezing|severe|sharp|bad) chest\b",
            r"\b(?:pain|pressure|tightness) in (?:my|the) chest\b",
            # D-96: any word order, e.g. "tight squeezing feeling in my chest", "heavy weight on my chest".
            r"\b(?:pains?|pressure|tight|tightness|squeez\w*|crush\w*|heaviness|burning|stabbing|aching)"
            r"(?: [a-z']+){0,3} (?:in|on|across|around|of) (?:my|the|his|her) chest\b",
            r"\b(?:heavy |a )?(?:weight|heaviness) (?:on|in) (?:my|the|his|her) chest\b",
            r"\bheavy (?:feeling|sensation) (?:on|in) (?:my|the|his|her) chest\b",
            r"\b(?:having|have) a heart attack\b",
            r"\b(?:think|thinks|might be|could be|is this) (?:it'?s |i'?m having )?a heart attack\b"]},
        {"id": "EM-STROKE", "category": "emergency", "spec": "FR-SAF-01", "patterns": [
            r"\b(?:having|have) a stroke\b",
            r"\bsigns? of (?:a )?stroke\b",
            r"\b(?:face|mouth) (?:is )?(?:drooping|droopy|droops)\b",
            r"\bdrooping (?:face|mouth)\b",
            # D-96: one-sided face symptoms.
            r"\b(?:half|one side|side|left side|right side) (?:of )?(?:my|his|her) face (?:is |went |has gone |feels |"
            r"suddenly |just )*(?:numb|droop\w*|dead|weak|paraly[sz]ed|frozen)\b",
            r"\b(?:ca" + NT + r"|unable to) smile (?:properly|normally|on one side|straight)\b",
            r"\bslurr(?:ed|ing) (?:speech|words)\b",
            r"\bsudden(?:ly)? (?:i )?(?:ca" + NT + r"|unable to) (?:speak|talk)\b",
            r"\b(?:ca" + NT + r"|unable to) (?:speak|talk) (?:properly|clearly|normally)\b",
            r"\b(?:trouble|difficulty|problems?) (?:speaking|talking)\b",
            r"\b(?:ca" + NT + r"|unable to) (?:lift|move) my (?:arm|leg)\b",
            r"\bsudden(?:ly)? (?:numb|numbness|weak|weakness|confused|confusion|blind)\b",
            r"\b(?:left|right) (?:arm|side|leg) (?:is |went |has gone |feels )?(?:numb|weak|dead)\b"]},
        {"id": "EM-BREATH", "category": "emergency", "spec": "FR-SAF-01", "patterns": [
            r"\b(?:ca" + NT + r"|unable to|struggling to|hard to|barely) breathe?\b",
            r"\b(?:severe|extreme|really bad) (?:shortness of breath|breathlessness)\b",
            r"\bgasping (?:for )?(?:air|breath)\b",
            # D-96: "I can hardly catch my breath".
            r"\b(?:ca" + NT + r"|can hardly|can barely|hardly|barely|unable to|struggling to) (?:catch|get) my breath\b",
            r"\bshort of breath (?:even )?(?:at rest|sitting|lying|when resting|while resting)\b",
            r"\bchoking\b"]},
        {"id": "EM-BLEED", "category": "emergency", "spec": "FR-SAF-01", "patterns": [
            r"\b(?:bleeding|blood) (?:wo" + NT + r"|will not|does" + NT + r"|is" + NT + r") stop",
            r"\b(?:heavy|severe|a lot of|lots of|uncontrolled) bleeding\b",
            r"\b(?:coughing|vomiting|throwing|spitting) (?:up )?blood\b"]},
        {"id": "EM-FAINT", "category": "emergency", "spec": "FR-SAF-01", "patterns": [
            r"\bfaint(?:ed|ing)\b",
            r"\b(?:feel|feeling|felt|going to|about to|might) faint\b",
            r"\bpass(?:ed|ing)? out\b",
            r"\b(?:lost|losing) consciousness\b",
            r"\b(?:collapsed|blacked out)\b",
            r"\bunconscious\b"]},
        {"id": "EM-OVERDOSE", "category": "emergency", "spec": "FR-SAF-01/02", "patterns": [
            r"\boverdos(?:e|ed|ing)\b",
            r"\btook (?:too many|a lot of|all (?:my|of my|the)|a whole (?:bottle|pack|strip) of) "
            r"(?:pills|tablets|meds|medicines?|medication|insulin|sleeping pills)\b"]},
        {"id": "CR-SUICIDE", "category": "crisis", "spec": "FR-SAF-02", "patterns": [
            r"\bsuicid(?:e|al)\b",
            r"\bkill(?:ing)? my ?self\b",
            r"\bend (?:my life|it all)\b",
            r"\b(?:do" + NT + r"|dont) want to (?:live|be alive|be here|exist|wake up)\b",
            r"\bwant to die\b",
            r"\bwish (?:i|i ?'?d) (?:was|were|had) (?:dead|never been born)\b",
            r"\bbetter off (?:dead|without me)\b",
            r"\bno (?:reason|point) (?:to|in) (?:live|living|going on)\b",
            r"\btake my (?:own )?life\b",
            r"\b(?:hurt|hurting|harm|harming|cut|cutting) my ?self\b",
            r"\bself ?harm\b",
            # D-96: indirect suicidal language and warning signs (FR-SAF-02).
            r"\bdisappear(?:ing)? (?:forever|for good|and never come back|and never coming back)\b",
            r"\b(?:sleep|go to sleep|fall asleep) and never (?:wake|waking) up\b",
            r"\b(?:never|not) (?:want to )?wake up again\b",
            r"\b(?:give|giving|given|gave) away (?:all )?(?:of )?my (?:things|stuff|belongings|possessions)\b"]},
        {"id": "CR-HINGLISH", "category": "crisis", "spec": "FR-SAF-02, D-03",
         "note": "Common romanised Hindi phrases. DRAFT: needs review by a clinician fluent in Hindi.",
         "patterns": [
            r"\bmar(?:na|ne|jaana|jana) (?:chahta|chahti|chahte)\b",
            r"\bkhud ?kushi\b",
            r"\bjeena nahi? (?:chahta|chahti|hai)\b",
            r"\bzinda nahi? (?:rehna|rahna)\b"]},
        {"id": "ED-RESTRICT", "category": "disordered_eating", "spec": "FR-SAF-04", "patterns": [
            r"\b[1-9][0-9]{1,2} (?:calories|cals|kcal|kcals) (?:a|per|each|every) day\b",
            r"\b(?:eat|eating|have|having) only [1-9][0-9]{1,2} (?:calories|cals|kcal)\b",
            r"\b(?:starve|starving) my ?self\b",
            r"\b(?:stop|stopped|quit) eating (?:completely|entirely|altogether|for days)\b",
            # D-96: going days without food; skipping every meal; restricting until a size or weight.
            r"\b(?:have" + NT + r"|havent|have not|not|did" + NT + r"|didnt|did not) (?:eaten|eat|had (?:any )?food)"
            r"(?: anything)? (?:in|for) (?:[2-9]|[1-9][0-9]|two|three|four|five|six|seven|several|a few|many) days\b",
            r"\b(?:skip|skipping|skipped) (?:all|every) (?:of )?(?:my )?meals?\b",
            r"\b(?:skip|skipping|not eating|no food|starv\w*)\b.*\buntil i (?:drop|lose|fit|weigh|get down)\b",
            r"\b(?:drop|lose|go down) (?:a|one|two|three|[1-9]) (?:dress |jean |clothes |pant )?sizes?\b"]},
        {"id": "ED-PURGE", "category": "disordered_eating", "spec": "FR-SAF-04", "patterns": [
            r"\b(?:make|making|made|force|forcing|forced) my ?self (?:to )?(?:throw up|vomit|be sick|sick|puke)\b",
            r"\bpurg(?:ed|ing) (?:after|my|food|meals)\b",
            r"\b(?:binge|binging|bingeing) (?:and|then) (?:purge|purging|throw up|vomit)\b",
            r"\blaxatives? (?:to|for) (?:lose|losing|weight)\b"]},
        {"id": "ED-CRASH", "category": "disordered_eating", "spec": "FR-SAF-04", "patterns": [
            r"\blose weight (?:really |super |very |so )?fast\b",
            r"\b(?:lose|drop) [0-9]+ ?(?:kg|kgs|kilos|kilograms|pounds|lbs) (?:in|by) "
            r"(?:a|one|two|three|[0-9]+) (?:day|days|week|weeks)\b",
            r"\b(?:hate|disgusted by|disgusted with) my (?:body|self)\b"]},
        {"id": "MED-CHANGE", "category": "medication", "spec": "FR-SAF-03", "patterns": [
            r"\b" + CHANGE + r"\b.*\b" + MEDS + r"\b",
            r"\b" + MEDS + r"\b.*\b" + CHANGE + r"\b",
            r"\b(?:how much|how many|what dose|which dose|right dose|dosage of)\b.*\b" + MEDS + r"\b"]},
        {"id": "MED-HINGLISH", "category": "medication", "spec": "FR-SAF-03, D-03, D-96",
         "note": "Romanised Hindi medicine changes. DRAFT: needs review by a clinician fluent in Hindi.",
         "patterns": [
            r"\b" + MEDS + r"\b.*\b" + HI_CHANGE + r"\b",
            r"\b" + HI_CHANGE + r"\b.*\b" + MEDS + r"\b",
            r"\b(?:kitni|kitna|kitne)\b.*\b" + MEDS + r"\b",
            r"\b(?:aadhi|adhi|aadha|adha|zyada|jyada|double) (?:goli|goliyan|dose|tablet|dawai|dawa|insulin)\b",
            r"\b" + MEDS + r"\b.*\b(?:kitni|kitna|kitne)\b"]},
        {"id": "MED-SUPPLEMENT", "category": "medication", "spec": "FR-SAF-03, 15.3", "patterns": [
            r"\bsupplement (?:stack|protocol|regimen|plan)\b",
            r"\b(?:how much|how many mg|what dose|which dose|dosage of)\b.*\b" + SUPPS + r"\b",
            r"\b" + SUPPS + r"\b.*\b(?:how much|dose|dosage|mg a day|mg per day)\b"]},
        {"id": "PREG", "category": "pregnancy_complex", "spec": "FR-SAF-05", "patterns": [
            r"\bpregnan(?:t|cy)\b",
            r"\bexpecting (?:a|our) baby\b",
            r"\bbreast ?feeding\b",
            r"\btrying to (?:conceive|get pregnant)\b",
            # D-96
            r"\btrimester\b",
            r"\bmorning sickness\b",
            r"\b(?:prenatal|antenatal) (?:check ?up|appointment|visit|scan|class)\b",
            r"\b(?:garbhvati|garbhavati|garbhwati)\b"]},
        {"id": "COMPLEX", "category": "pregnancy_complex", "spec": "FR-SAF-05", "patterns": [
            r"\bdialysis\b",
            r"\bchemo(?:therapy)?\b",
            r"\b(?:kidney|liver|heart) (?:failure|disease|transplant)\b",
            r"\btype 1 diabetes\b",
            r"\bhad a (?:stroke|heart attack)\b",
            r"\b(?:history of|since my|after my) (?:a )?(?:stroke|heart attack)\b"]},
    ],
}

with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(rules, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("rules:", len(rules["rules"]), "patterns:", sum(len(r["patterns"]) for r in rules["rules"]))
