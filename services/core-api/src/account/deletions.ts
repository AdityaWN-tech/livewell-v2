import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';

/**
 * Deletions the app can't do itself (firestore.rules forbid client deletes):
 * "Delete my avatar", "Delete my voice" (FR-SET-03, one tap each, with
 * confirmation in the app) and "Delete my account" (FR-SET-02, spec 16.3).
 * Each writes an audit entry with no health content. Callable only by the
 * signed-in owner; the uid always comes from the auth token, never from
 * the request body.
 */

function uidOf(auth: { uid: string } | undefined): string {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return auth.uid;
}

/** Unique per call, so repeated deletions each get an entry. */
const stamp = () => Date.now().toString(36);

export async function deleteAvatarFor(uid: string, log: AuditLog) {
  const ref = getFirestore().doc(`users/${uid}/avatar/current`);
  const existed = (await ref.get()).exists;
  await ref.delete();
  // TODO(T-AVT-03): when a vendor avatar exists, delete it by API first and
  // record the vendor's confirmation (FR-SET-03).
  await log.append(`avatar_deleted_${uid}_${stamp()}`, {
    actor: uid,
    action: 'avatar.deleted',
    target: `users/${uid}/avatar/current`,
    details: { existed, vendor_models_deleted: 0 },
  });
  return { deleted: existed };
}

export async function deleteVoicesFor(uid: string, log: AuditLog) {
  const voices = await getFirestore().collection(`users/${uid}/voices`).get();
  const clones = voices.docs.filter((d) => d.get('kind') !== 'library').length;
  await Promise.all(voices.docs.map((d) => d.ref.delete()));
  // TODO(T-VOC-03): delete cloned voice models at the vendor by API and log
  // the confirmation (FR-SET-03, within 24 h per spec 16.3).
  await log.append(`voice_deleted_${uid}_${stamp()}`, {
    actor: uid,
    action: 'voice.deleted',
    target: `users/${uid}/voices`,
    details: { count: voices.size, cloned: clones },
  });
  return { deleted: voices.size };
}

export async function deleteAccountFor(uid: string, log: AuditLog) {
  const db = getFirestore();
  // Logged first, so the request is recorded even if a later step fails
  // and is retried (the log id is fixed per account).
  await log.append(`account_deleted_${uid}`, {
    actor: uid,
    action: 'account.deleted',
    target: `users/${uid}`,
    details: { requested_in_app: true },
  });
  // The profile and every sub-collection (check-ins, plans, consents, …).
  await db.recursiveDelete(db.doc(`users/${uid}`));
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
  }
  return { deleted: true };
}

export function makeDeletions(log: AuditLog = new FirestoreAuditLog()) {
  return {
    deleteAvatar: onCall((req) => deleteAvatarFor(uidOf(req.auth), log)),
    deleteVoice: onCall((req) => deleteVoicesFor(uidOf(req.auth), log)),
    deleteAccount: onCall((req) => deleteAccountFor(uidOf(req.auth), log)),
  };
}
