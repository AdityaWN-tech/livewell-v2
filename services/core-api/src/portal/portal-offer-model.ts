import { z } from 'zod';

import { hasAny, type Staff, type StaffRole } from '../admin/staff.js';

/**
 * Portal catalog (spec 11 `portal_offers`, 13.2, 13.4; T-PRT-02, D-92).
 * Pure code: validation and the review workflow, no Firestore, so every
 * rule is unit-tested. HUMAN REVIEW REQUIRED (security, roles).
 */

/** Hosts an offer may link to (spec 13.1: the Live Well Portal on TagMango). */
export const PORTAL_HOSTS = ['livewell.conciergeconnectedcare.net'] as const;

export const OFFER_TYPES = ['course', 'program', 'free_lesson', 'coaching'] as const;
export type OfferType = (typeof OFFER_TYPES)[number];

export const REVIEW_STATUSES = ['draft', 'in_review', 'approved', 'rejected', 'archived'] as const;
export type ReviewStatus = (typeof REVIEW_STATUSES)[number];

/** Query parameters the app adds itself (spec 13.2 attribution). */
const RESERVED_PARAMS = /^(utm_[a-z_]*|lw_cid)$/i;

// Letters, digits, punctuation and spaces; no control characters or newlines.
const CONTROL_CHARS = /[\u0000-\u001f\u007f\u2028\u2029]/;
const oneLine = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .refine((s) => !CONTROL_CHARS.test(s), 'one line, no control characters');

const tag = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z][a-z0-9_]{0,31}$/, 'tags are lowercase letters, digits and _');

const tags = z
  .array(tag)
  .max(8)
  .transform((t) => [...new Set(t)]);

export const offerUrl = z
  .string()
  .trim()
  .max(500)
  .refine((s) => {
    let u: URL;
    try {
      u = new URL(s);
    } catch {
      return false;
    }
    return (
      u.protocol === 'https:' &&
      (PORTAL_HOSTS as readonly string[]).includes(u.hostname) &&
      u.port === '' &&
      u.username === '' &&
      u.password === '' &&
      u.hash === '' &&
      ![...u.searchParams.keys()].some((k) => RESERVED_PARAMS.test(k))
    );
  }, `an https link on ${PORTAL_HOSTS.join(', ')}, with no utm_ or lw_cid parameters (the app adds them)`);

/** What an editor writes. The id, status and workflow are the server's. */
export const offerFieldsSchema = z
  .object({
    title: oneLine(80).pipe(z.string().min(3)),
    description: oneLine(240).optional().default(''),
    url: offerUrl,
    offer_type: z.enum(OFFER_TYPES),
    driver_tags: tags.optional().default([]),
    topic_tags: tags.optional().default([]),
    /** Shown exactly as entered (spec 13.4), e.g. "$49". Empty: "Paid course". */
    price_display: oneLine(24).optional().default(''),
  })
  .strict()
  .refine((o) => o.offer_type !== 'free_lesson' || o.price_display === '', {
    path: ['price_display'],
    message: 'a free lesson has no price',
  });

export type OfferFields = z.output<typeof offerFieldsSchema>;
export const OFFER_FIELD_KEYS = [
  'title',
  'description',
  'url',
  'offer_type',
  'driver_tags',
  'topic_tags',
  'price_display',
] as const satisfies readonly (keyof OfferFields)[];

const offerId = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);
const rev = z.number().int().min(1);

export const createRequest = z.object({ fields: offerFieldsSchema }).strict();
export const updateRequest = z
  .object({ id: offerId, expected_rev: rev, fields: offerFieldsSchema })
  .strict();

export const TRANSITIONS = [
  'submit',
  'withdraw',
  'approve',
  'reject',
  'publish',
  'unpublish',
  'archive',
  'restore',
] as const;
export type Transition = (typeof TRANSITIONS)[number];

export const transitionRequest = z
  .object({ id: offerId, expected_rev: rev, action: z.enum(TRANSITIONS) })
  .strict();

/** The state the workflow reads and writes. */
export interface OfferState {
  review_status: ReviewStatus;
  active: boolean;
  version: number;
  /** Staff who changed the content since the last approval. */
  version_editors: string[];
  submitted_by: string | null;
}

/** Roles per transition (D-92). Editing and creating: content_editor, admin. */
export const EDIT_ROLES: readonly StaffRole[] = ['content_editor', 'admin'];
export const ROLES: Record<Transition, readonly StaffRole[]> = {
  submit: EDIT_ROLES,
  withdraw: EDIT_ROLES,
  approve: ['clinical_reviewer', 'admin'],
  reject: ['clinical_reviewer', 'admin'],
  // "Editors can publish offers" (17.4 T-PRT-02): only once approved.
  publish: EDIT_ROLES,
  // Taking an offer down is safe, so every staff role may do it.
  unpublish: ['content_editor', 'clinical_reviewer', 'safety_reviewer', 'admin'],
  archive: EDIT_ROLES,
  restore: EDIT_ROLES,
};

export type WorkflowError =
  | 'role'
  | 'wrong_status'
  | 'own_offer'
  | 'not_active'
  | 'already_active';

/**
 * The state after [action], or why it is refused. Two-person rule: nobody
 * approves an offer they edited in this version or submitted, admins
 * included (spec 16.2, ADR-003 risks; D-92).
 */
export function applyTransition(
  s: OfferState,
  action: Transition,
  staff: Staff,
): { ok: true; next: OfferState } | { ok: false; error: WorkflowError } {
  if (!hasAny(staff, ROLES[action])) return { ok: false, error: 'role' };
  const st = s.review_status;
  const to = (patch: Partial<OfferState>) => ({ ok: true as const, next: { ...s, ...patch } });
  switch (action) {
    case 'submit':
      if (st !== 'draft' && st !== 'rejected') return { ok: false, error: 'wrong_status' };
      return to({ review_status: 'in_review', active: false, submitted_by: staff.uid });
    case 'withdraw':
      if (st !== 'in_review') return { ok: false, error: 'wrong_status' };
      return to({ review_status: 'draft', submitted_by: null });
    case 'approve':
      if (st !== 'in_review') return { ok: false, error: 'wrong_status' };
      if (s.version_editors.includes(staff.uid) || s.submitted_by === staff.uid) {
        return { ok: false, error: 'own_offer' };
      }
      // Approved, not yet live: an editor publishes it.
      return to({ review_status: 'approved', active: false, version_editors: [] });
    case 'reject':
      if (st !== 'in_review') return { ok: false, error: 'wrong_status' };
      return to({ review_status: 'rejected', active: false, submitted_by: null });
    case 'publish':
      if (st !== 'approved') return { ok: false, error: 'wrong_status' };
      if (s.active) return { ok: false, error: 'already_active' };
      return to({ active: true });
    case 'unpublish':
      if (!s.active) return { ok: false, error: 'not_active' };
      return to({ active: false });
    case 'archive':
      if (st === 'archived') return { ok: false, error: 'wrong_status' };
      return to({ review_status: 'archived', active: false, submitted_by: null });
    case 'restore':
      if (st !== 'archived') return { ok: false, error: 'wrong_status' };
      // Back to a draft: it must be reviewed again before it can go live.
      return to({ review_status: 'draft', active: false, version_editors: [staff.uid] });
  }
}

/**
 * An edit: any change to the content takes the offer offline and back to
 * draft, so nothing unreviewed is ever live (spec 11.1, 13.4).
 */
export function applyEdit(s: OfferState, staff: Staff): { ok: true; next: OfferState } | { ok: false; error: WorkflowError } {
  if (!hasAny(staff, EDIT_ROLES)) return { ok: false, error: 'role' };
  if (s.review_status === 'archived') return { ok: false, error: 'wrong_status' };
  return {
    ok: true,
    next: {
      review_status: 'draft',
      active: false,
      version: s.version + 1,
      version_editors: s.version_editors.includes(staff.uid)
        ? s.version_editors
        : [...s.version_editors, staff.uid],
      submitted_by: null,
    },
  };
}

/** Which content fields differ (names only, for the audit log). */
export function changedFields(before: Partial<OfferFields>, after: OfferFields): string[] {
  return OFFER_FIELD_KEYS.filter(
    (k) => JSON.stringify(before[k] ?? null) !== JSON.stringify(after[k]),
  );
}
