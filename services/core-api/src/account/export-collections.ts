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
] as const;

/** Sub-collections of users/{uid} left out, and why. */
export const EXCLUDED_USER_COLLECTIONS: Record<string, string> = {
  data_exports: 'The export requests themselves (status only, no personal data).',
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
