# Safety rules (red flags)

Deterministic red-flag rules (T-ASM-02, FR-SAF-01..05), shared by every part of Live Well that reads user text: the app now, the agents service (T-AGT-02) later.
**HUMAN REVIEW REQUIRED:** the Clinical Content and Safety Committee reviews the rules, the test cases and the messages shown (app ARB `safety*` strings) before launch. Version `0.1-draft`.

| File | What |
|---|---|
| `build_rules.py` | **Edit this.** Source of the rules (shared word lists, patterns). |
| `rules.json` | Generated: `python build_rules.py rules.json`. Bundled in the app as `apps/mobile/assets/safety/rules.json` (copy it there too; a test checks they match). |
| `cases.json` | Shared test set. `critical: true` cases must route correctly 100% of the time (spec 15.2). Add a case for every miss or false alarm found. |
| `check_cases.py` | Reference engine + runner: `python check_cases.py` (exit 1 on any failure). |
| `label_rules.json` | **Short-label rules** for custom My Daily Routine items (T-GOL-03c), checked after `rules.json`. Kinds: disordered_eating, medication (not a routine item in v2), not_allowed (weight, calories, fasting, diets), unkind. Hand-edited. Bundled as `apps/mobile/assets/safety/label_rules.json` (a test checks they match). |
| `label_cases.json` / `check_label_cases.py` | Label test set and runner: `python check_label_cases.py`. `critical` cases: eating-disorder signs always caught, everyday steps never blocked. |

Categories by priority: emergency, crisis (both interrupt with one-tap calls), disordered eating, medication, pregnancy / medically complex. Numbers per region (D-03): US 911 and 988 (call or text); India 112 and Tele-MANAS 14416; unknown region shows both.
Rules are keyword patterns; the spec's classifier redundancy comes with the agents service (T-AGT-02).
