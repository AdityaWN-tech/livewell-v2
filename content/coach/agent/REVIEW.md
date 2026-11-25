# Coach Agent fixed texts: clinical review (T-AGT-04, D-98)

Used only when the Coach Agent cannot use a model-written text in a mode (model unavailable, draft failed Safety.post, classifier failed, prompt not approved here, instruction-like input, or a safety event in the last 72 hours). No placeholders, nothing the person typed. Red flags never use these: they use the safety cards and the neutral voice. The morning briefing keeps `moments/morning.json` `m6`. All `pending` until approved.

| id | Mode | Line | Approved? |
|---|---|---|---|
| `reply_f1` | reply (conversation turn) | Thanks for telling me. I don't have a good answer for that right now. For questions about your health, your doctor is the best person to ask. Your plan for today is still here, and one small step is enough. | ☐ |
| `nudge_f1` | nudge | It's a good moment for your step. Shall we start? | ☐ |
| `reflection_f1` | evening reflection reply | Thank you for sharing your evening with me. Every day teaches us something. Rest well, and we'll take the next small step together tomorrow. | ☐ |
| `weekly_review_f1` | weekly review (same words as `weekly_review.w3`) | A new week is a fresh start. Want to look back at your week together? | ☐ |

Fixed buttons (app copy, never model output): nudge `start_step` (also `done`, `make_smaller`, `not_today`); reflection `close`; weekly review `see_week`; reply has none.

The five Coach prompts (`services/agents/prompts/coach_*`) are also `pending` and need the same committee's approval before staging or prod may use them.
