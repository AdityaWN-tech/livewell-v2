import {
  FieldValue,
  getFirestore,
  type DocumentData,
  type Timestamp,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import type { z } from 'zod';

import type { AuditAction } from '../audit/audit-actions.js';
import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';
import { requireStaff, STAFF_ROLES, type Staff, type TokenLike } from '../admin/staff.js';
import {
  applyEdit,
  applyTransition,
  changedFields,
  createRequest,
  EDIT_ROLES,
  OFFER_FIELD_KEYS,
  ROLES,
  transitionRequest,
  updateRequest,
  type OfferFields,
  type OfferState,
  type Transition,
  type WorkflowError,
} from './portal-offer-model.js';

/**
 * Admin callables for the portal catalog (T-PRT-02, D-92). Every call is
 * role-checked and MFA-gated (admin/staff.ts) and every write is audited
 * with ids, statuses and changed field names only (no offer text).
 *
 * Storage:
 * - `portal_offers/{id}`: what the app reads (spec 11); clients see only
 *   `active == true && review_status == 'approved'` (firestore.rules).
 * - `portal_offer_workflow/{id}`: who did what (staff uids), server-only,
 *   so staff ids never reach app users.
 * Writes are transactions with optimistic concurrency (`expected_rev`), so
 * two staff members can't overwrite each other's change unknowingly.
 */

const OFFERS = 'portal_offers';
const WORKFLOW = 'portal_offer_workflow';
const SCHEMA_VERSION = 1;

type Auth = CallableRequest['auth'];

function staffOf(auth: Auth, allowed: Parameters<typeof requireStaff>[1]): Staff {
  return requireStaff(auth as { uid: string; token: TokenLike } | undefined, allowed);
}

function parse<T extends z.ZodType>(schema: T, data: unknown): z.output<T> {
  const r = schema.safeParse(data);
  if (!r.success) {
    throw new HttpsError('invalid-argument', 'Some fields are not valid.', {
      reason: 'invalid',
      issues: r.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
    });
  }
  return r.data;
}

const WORKFLOW_MESSAGES: Record<WorkflowError, string> = {
  role: 'Your role cannot do this.',
  wrong_status: 'The offer is not in a state that allows this.',
  own_offer: 'Someone other than the editors of this version must approve it.',
  not_active: 'The offer is not live.',
  already_active: 'The offer is already live.',
};

function refuse(error: WorkflowError): never {
  throw new HttpsError(
    error === 'role' ? 'permission-denied' : 'failed-precondition',
    WORKFLOW_MESSAGES[error],
    { reason: error },
  );
}

/** One offer as staff see it (public fields + workflow). */
export interface AdminOffer extends OfferFields {
  id: string;
  review_status: OfferState['review_status'];
  active: boolean;
  version: number;
  rev: number;
  version_editors: string[];
  submitted_by: string | null;
  created_by: string | null;
  last_action: string | null;
  last_actor: string | null;
  updated_at: string | null;
}

function toAdmin(id: string, o: DocumentData, w: DocumentData | undefined): AdminOffer {
  const ts = o.updated_at as Timestamp | undefined;
  return {
    id,
    title: (o.title as string) ?? '',
    description: (o.description as string) ?? '',
    url: (o.url as string) ?? '',
    offer_type: o.offer_type as OfferFields['offer_type'],
    driver_tags: (o.driver_tags as string[]) ?? [],
    topic_tags: (o.topic_tags as string[]) ?? [],
    price_display: (o.price_display as string) ?? '',
    review_status: o.review_status as OfferState['review_status'],
    active: o.active === true,
    version: (o.version as number) ?? 1,
    rev: (w?.rev as number) ?? 1,
    version_editors: (w?.version_editors as string[]) ?? [],
    submitted_by: (w?.submitted_by as string) ?? null,
    created_by: (w?.created_by as string) ?? null,
    last_action: (w?.last_action as string) ?? null,
    last_actor: (w?.last_actor as string) ?? null,
    updated_at: ts ? ts.toDate().toISOString() : null,
  };
}

function stateOf(o: DocumentData, w: DocumentData | undefined): OfferState {
  return {
    review_status: o.review_status as OfferState['review_status'],
    active: o.active === true,
    version: (o.version as number) ?? 1,
    version_editors: (w?.version_editors as string[]) ?? [],
    submitted_by: (w?.submitted_by as string) ?? null,
  };
}

const AUDIT_ACTION: Record<Transition | 'create' | 'update', AuditAction> = {
  create: 'admin.portal_offer_created',
  update: 'admin.portal_offer_updated',
  submit: 'admin.portal_offer_submitted',
  withdraw: 'admin.portal_offer_withdrawn',
  approve: 'admin.portal_offer_approved',
  reject: 'admin.portal_offer_rejected',
  publish: 'admin.portal_offer_published',
  unpublish: 'admin.portal_offer_unpublished',
  archive: 'admin.portal_offer_archived',
  restore: 'admin.portal_offer_restored',
};

async function audit(
  log: AuditLog,
  staff: Staff,
  id: string,
  rev: number,
  kind: keyof typeof AUDIT_ACTION,
  details: Record<string, string | number | boolean>,
) {
  try {
    // One entry per revision of the offer: unique, and idempotent on retry.
    await log.append(`portal_offer_${id}_r${rev}`, {
      actor: `admin:${staff.uid}`,
      action: AUDIT_ACTION[kind],
      target: `${OFFERS}/${id}`,
      details: { ...details, rev, mfa: staff.mfa },
    });
  } catch {
    // The change is saved; make the gap visible (ids only) and fail the call
    // so the admin sees it. See D-92 (audit after the transaction).
    logger.error('portal_offer audit write failed', { offer_id: id, rev, action: kind });
    throw new HttpsError('internal', 'Saved, but the audit entry failed. Tell the owner.');
  }
}

export async function listOffers(staff: Staff): Promise<{ offers: AdminOffer[] }> {
  void staff;
  const db = getFirestore();
  const [offers, flows] = await Promise.all([
    db.collection(OFFERS).orderBy('updated_at', 'desc').limit(500).get(),
    db.collection(WORKFLOW).limit(1000).get(),
  ]);
  const byId = new Map(flows.docs.map((d) => [d.id, d.data()]));
  return { offers: offers.docs.map((d) => toAdmin(d.id, d.data(), byId.get(d.id))) };
}

export async function createOffer(staff: Staff, data: unknown, log: AuditLog) {
  const { fields } = parse(createRequest, data);
  const db = getFirestore();
  const ref = db.collection(OFFERS).doc();
  const now = FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.create(ref, {
    ...fields,
    review_status: 'draft',
    active: false,
    version: 1,
    created_at: now,
    updated_at: now,
    schema_version: SCHEMA_VERSION,
  });
  batch.create(db.collection(WORKFLOW).doc(ref.id), {
    rev: 1,
    created_by: staff.uid,
    version_editors: [staff.uid],
    submitted_by: null,
    last_action: 'create',
    last_actor: staff.uid,
    created_at: now,
    updated_at: now,
    schema_version: SCHEMA_VERSION,
  });
  await batch.commit();
  await audit(log, staff, ref.id, 1, 'create', {
    to: 'draft',
    version: 1,
    fields: OFFER_FIELD_KEYS.join(','),
  });
  return { id: ref.id, rev: 1 };
}

/** Loads both documents in [tx] and checks the caller's expected revision. */
async function load(tx: Transaction, id: string, expectedRev: number) {
  const db = getFirestore();
  const oRef = db.collection(OFFERS).doc(id);
  const wRef = db.collection(WORKFLOW).doc(id);
  const [o, w] = await Promise.all([tx.get(oRef), tx.get(wRef)]);
  if (!o.exists) throw new HttpsError('not-found', 'No such offer.', { reason: 'not_found' });
  const rev = (w.get('rev') as number | undefined) ?? 1;
  if (rev !== expectedRev) {
    throw new HttpsError('aborted', 'Someone changed this offer. Reload and try again.', {
      reason: 'stale',
    });
  }
  return { oRef, wRef, o: o.data()!, w: w.data(), rev };
}

export async function updateOffer(staff: Staff, data: unknown, log: AuditLog) {
  const req = parse(updateRequest, data);
  const db = getFirestore();
  const result = await db.runTransaction(async (tx) => {
    const { oRef, wRef, o, w, rev } = await load(tx, req.id, req.expected_rev);
    const fields = changedFields(o as Partial<OfferFields>, req.fields);
    if (fields.length === 0) return { rev, fields, from: o.review_status as string, to: null };
    const r = applyEdit(stateOf(o, w), staff);
    if (!r.ok) refuse(r.error);
    const now = FieldValue.serverTimestamp();
    tx.update(oRef, {
      ...req.fields,
      review_status: r.next.review_status,
      active: r.next.active,
      version: r.next.version,
      updated_at: now,
    });
    tx.set(
      wRef,
      {
        rev: rev + 1,
        version_editors: r.next.version_editors,
        submitted_by: r.next.submitted_by,
        last_action: 'update',
        last_actor: staff.uid,
        updated_at: now,
        schema_version: SCHEMA_VERSION,
      },
      { merge: true },
    );
    return {
      rev: rev + 1,
      fields,
      from: o.review_status as string,
      to: r.next.review_status as string,
      wasActive: o.active === true,
      version: r.next.version,
    };
  });
  if (result.to === null) return { id: req.id, rev: result.rev, changed: false };
  await audit(log, staff, req.id, result.rev, 'update', {
    from: result.from,
    to: result.to,
    was_active: result.wasActive ?? false,
    version: result.version ?? 0,
    fields: result.fields.join(','),
  });
  return { id: req.id, rev: result.rev, changed: true };
}

export async function transitionOffer(staff: Staff, data: unknown, log: AuditLog) {
  const req = parse(transitionRequest, data);
  const db = getFirestore();
  const result = await db.runTransaction(async (tx) => {
    const { oRef, wRef, o, w, rev } = await load(tx, req.id, req.expected_rev);
    const before = stateOf(o, w);
    const r = applyTransition(before, req.action, staff);
    if (!r.ok) refuse(r.error);
    const now = FieldValue.serverTimestamp();
    tx.update(oRef, {
      review_status: r.next.review_status,
      active: r.next.active,
      updated_at: now,
    });
    tx.set(
      wRef,
      {
        rev: rev + 1,
        version_editors: r.next.version_editors,
        submitted_by: r.next.submitted_by,
        last_action: req.action,
        last_actor: staff.uid,
        updated_at: now,
        schema_version: SCHEMA_VERSION,
      },
      { merge: true },
    );
    return { rev: rev + 1, before, next: r.next };
  });
  await audit(log, staff, req.id, result.rev, req.action, {
    from: result.before.review_status,
    to: result.next.review_status,
    active: result.next.active,
    version: result.next.version,
  });
  return {
    id: req.id,
    rev: result.rev,
    review_status: result.next.review_status,
    active: result.next.active,
  };
}

const ANY_STAFF = STAFF_ROLES;
// Any staff role may call transition; the workflow checks the role per action.
const TRANSITION_CALLERS = [...new Set(Object.values(ROLES).flat())];

export function makePortalOfferCallables(log: AuditLog = new FirestoreAuditLog()) {
  return {
    adminListPortalOffers: onCall((req) => listOffers(staffOf(req.auth, ANY_STAFF))),
    adminCreatePortalOffer: onCall((req) =>
      createOffer(staffOf(req.auth, EDIT_ROLES), req.data, log),
    ),
    adminUpdatePortalOffer: onCall((req) =>
      updateOffer(staffOf(req.auth, EDIT_ROLES), req.data, log),
    ),
    adminTransitionPortalOffer: onCall((req) =>
      transitionOffer(staffOf(req.auth, TRANSITION_CALLERS), req.data, log),
    ),
  };
}
