# Data model (Firestore)

Source: spec Section 11. Security rules: `firebase/firestore.rules` (T-FND-06, human review required).
Database: Standard `(default)` in nam5 per project (D-16). Every document carries `created_at`, `updated_at`, `schema_version`.
App code gets Firestore only through `firestoreProvider` (D-16).

| Path | Key fields | App (client) access | Written by server |
|---|---|---|---|
| `users/{uid}` | display_name, email, tz, locale, region, age_confirmed, onboarding_step (`avatar` → `voice` → `why` → `assessment`), focus_driver, why_statement | Owner read; create only with `age_confirmed == true`; update listed fields only; no delete | plan_tier, ed_safe_mode, safety state; account deletion |
| `users/{uid}/consents/{id}` | type, doc_version, granted, granted_at, revoked_at, app_version, evidence_ref | Owner read; **append-only** create (created_at = server time); no update/delete | — |
| `users/{uid}/avatar/current` | type (stylized \| photoreal), style_config, raw_media_retained | Owner read; create/update those fields; no delete. **style_config v1** (T-ONB-03b): `version`, `skin` (0–9, Monk scale), `hair` (none/short/long/curly/coily/wavy/bun/buzz), `hair_colour` (0–6), `eyes` (round/almond/smiling), `glasses` (none/round/square), `head_covering` (none/hijab/turban/kippah), `clothing` (crew/collar/cardigan), `clothing_colour` (0–5), `background` (0–5), `look` (woman/man/neutral, only if chosen). The app always writes `type: stylized`, `raw_media_retained: false` | vendor, vendor_avatar_id, thumbnail_urls; deletion |
| `users/{uid}/voices/{voice_id}` | kind, vendor_voice_id, consent_id, status, speed, style | Owner read. **Library voices** (T-ONB-03c): the app creates them (`kind: library`, id `lw-…` from the app catalogue, status active/inactive, speed 0.8–1.2, style calm/energetic, fixed keys) and switches which one is active. Any voice: update speed and style. One active at a time (the app deactivates the others) | cloned voices: create, status, revoke |
| `voice_consents/{id}` | consent record (spec 11 example) | **None** | all |
| `users/{uid}/assessments/{id}` | bank_version, answers[], driver_scores, red_flags, map_result, completed_at | Owner read; create; update until completed; bank_version fixed | — |
| `users/{uid}/goals/{id}` | SMART fields, FITT, status, driver | Owner read/create/update; no delete (pause) | — |
| `users/{uid}/habits/{id}` | goal_id, title, anchor, window, size_variants, active | Owner read/create/update; no delete | — |
| `users/{uid}/habit_logs/{date_habitId}` | date, habit_id, status, source, size_done | Owner read/create/update; id must equal `date_habitId`; date and habit fixed | — |
| `users/{uid}/checkins/{date}` | mood (1–5, required), energy, sleep, stress (1–5, optional), time_available (2/5/10/30, optional), barrier_text (≤ 140, optional), source, gentle_day (bool) | Owner read/create/update; id `YYYY-MM-DD` (local date); created_at never changes; **mood ≤ 2 or stress ≥ 4 must have gentle_day = true** (T-DLY-02) | — |
| `users/{uid}/reflections/{date}` | text (1–500), prompt (`went_well`), source (`app`) | Owner read/create/update; id `YYYY-MM-DD` (local date); created_at never changes; no delete. Not in spec section 11 (added for FR-DLY-05 / T-UI-01d). Red-flag text is checked in the app and not saved | — |
| `users/{uid}/daily_plans/{date}` | next_step, alternatives, briefing ids/urls, mode | Owner read only | nightly job |
| `users/{uid}/messages/{id}` | CoachMessage (spec 9.5) | Owner read only | orchestrator |
| `users/{uid}/memory_facts/{id}` | fact, category, confidence, source_message_id, status | Owner read; change status to saved/deleted only; deleted is final | Memory Agent proposals |
| `users/{uid}/streaks/current` | length, grace_used_week, best, restart_count | Owner read only | streak engine |
| `users/{uid}/portal_link/{doc}` | tagmango_customer_ref, matched_email_hash, status | Owner read only | link/unlink |
| `users/{uid}/portal_events/{id}` | event, offer_id, click_id, value | Owner read; **append-only** create of card_shown / clicked / dismissed | order / progress / completed (webhooks) |
| `portal_offers/{id}` | title, url, offer_type, tags, price_display, active, review_status | Signed-in read of active + approved only (queries must filter the same way) | Admin |
| `content_items/{id}` | lesson metadata, body, media | Signed-in read of approved only | Admin |
| `safety_events/{id}` | — | **None** | all |
| `audit_log/{id}` | actor, action, target, timestamp, ip_hash, details (no health content) | **None** | Cloud Functions; interim Firestore store (D-18), idempotent ids e.g. `consent_{uid}_{consentId}` |

Anything not listed is denied.
