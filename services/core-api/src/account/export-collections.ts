/**
 * What "Download my data" (FR-SET-02, T-CMP-03, D-82) puts in the export.
 *
 * Every collection in docs/data-model.md must appear here exactly once,
 * either as exported or as excluded with a reason. test/export-collections
 * .test.ts reads docs/data-model.md and fails when a collection is missing,
 * so a new collection can't be left out of the export silently.
 */

/** Sub-collections of users/{uid} that go into the export, in this order. */
export const EXPORTED_USER_COLLECTIONS = [
  'consents',
  'avatar',
  'voices',
  'assessments',
  'goals',
  'habits',
  'habit_logs',
  'checkins',
  'reflections',
  // Weight, blood pressure, glucose and meals the person recorded (T-GOL-02, D-72).
  'metrics',
  // Badges earned and challenges joined (T-GAM-01, D-87).
  'rewards',
  'challenges',
  'routines',
  'routine_items',
  'routine_logs',
  'daily_plans',
  'messages',
  'memory_facts',
  'streaks',
  'portal_link',
  'content_progress',
  'portal_events',
  // The prototype's goals, affirmations and favourites (T-FND-07, D-83).
  'legacy_goals',
  'legacy_affirmations',
  'legacy_favorites',
] as const;

/** Sub-collections of users/{uid} left out, and why. */
export const EXCLUDED_USER_COLLECTIONS: Record<string, string> = {
  data_exports: 'The export requests themselves (status only, no personal data).',
  devices:
    'Push delivery token, platform and time zone (T-TCH-01): technical, and a token is a credential. Needs counsel (D-82).',
  push_days: 'Server counter for the daily push cap (a number per day), no content.',
};

/** Top-level collections: none holds only this person's data. */
export const EXCLUDED_TOP_LEVEL_COLLECTIONS: Record<string, string> = {
  voice_consents:
    'Server-only consent evidence; may hold another person’s data (the loved-one voice owner). Needs counsel (D-82).',
  portal_offers: 'Shared catalogue, not personal data.',
  content_items: 'Shared catalogue, not personal data.',
  safety_events:
    'Restricted safety-review records (spec 11.1). Needs counsel (D-82).',
  audit_log:
    'Security record, no health content (spec 16.3). Needs counsel (D-82).',
  portal_offer_workflow: 'Staff review workflow for the shared catalogue (T-PRT-02), not personal data.',
  consent_revocations:
    'Server task records for revoke handling (D-76); the consents themselves are exported. Needs counsel (D-82).',
  vendor_requests:
    'Server queue of vendor-side deletions (D-76): ids and status only. Needs counsel (D-82).',
  marketing_suppressions:
    'Marketing stop-list entry (D-76); the marketing consent records are exported.',
  push_outbox: 'Server queue of push requests (category and an id only), consumed on sending.',
};

/**
 * Internal fields removed from every exported document, at any depth
 * (spec 11.1 "server-only fields (vendor IDs, safety state)"): vendor ids,
 * matching hashes, internal media links and safety-review state.
 */
export function isInternalField(key: string): boolean {
  return (
    key === 'vendor' ||
    key.startsWith('vendor_') ||
    key.endsWith('_hash') ||
    key.endsWith('_url') ||
    key.endsWith('_urls') ||
    key.startsWith('safety') ||
    key === 'ed_safe_mode' ||
    key === 'tagmango_customer_ref'
  );
}

/** Cloud Storage folders that belong to one person (listed, not copied). */
export const USER_STORAGE_PREFIXES = (uid: string) => [`avatars/${uid}/`];

/** Where export files are kept; deleted after [EXPORT_TTL_DAYS]. */
export const exportPrefix = (uid: string) => `exports/${uid}/`;
export const exportPath = (uid: string, jobId: string) =>
  `${exportPrefix(uid)}${jobId}.zip`;

export const EXPORT_TTL_DAYS = 7;
export const RATE_LIMIT_HOURS = 24;
/** A job still "preparing" after this long is treated as failed. */
export const STALE_AFTER_MINUTES = 60;
/** Download links work for this long after they are made. */
export const LINK_TTL_MINUTES = 15;
