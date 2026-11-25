import { createHash } from 'node:crypto';

import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
} from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import type { AuditLog } from '../audit/audit-log.js';

/**
 * What happens on the server when a consent is revoked (FR-ONB-03 → spec
 * 16.3, within 24 hours; D-76). HUMAN REVIEW REQUIRED (consent).
 *
 * Each revocation record (users/{uid}/consents/{id} with granted == false)
 * gets one task document, `consent_revocations/{uid}_{consentId}`. The
 * consent trigger runs it straight away; the hourly sweep retries any task
 * that is not done and re-runs recent ones once more, so data written by a
 * job that was already running when the person revoked is removed too.
 * Every step is idempotent: running a task twice deletes nothing new and
 * never fails because something is already gone.
 *
 * Every finished task writes one audit entry with ids, the consent type,
 * the steps and counts only: never content (spec 16.3).
 */

/** One kind of server-side handling. */
export type RevokeStep =
  /** Selfies, face data, photo-avatar sources and frames; vendor avatar. */
  | 'face_data'
  /** Raw voice samples and consent audio; cloned voices; vendor voice. */
  | 'voice_data'
  /** Portal link removed, portal events deleted; TagMango unlink queued. */
  | 'portal_unlink'
  /** Marketing suppressed; email-provider unsubscribe queued. */
  | 'marketing_stop';

/**
 * Steps per consent type (D-76). Where 16.3 is not explicit the most
 * conservative choice is taken (delete or stop more, never less):
 * camera also removes the face data made from the selfie, and microphone
 * also removes voice copies made from recordings.
 *
 * notifications, health_data and analytics have no server-held data: the
 * app stops on the device (no reminders, no Health reads, analytics
 * collection off). They still get an audit entry with no steps. The legal
 * documents can't be revoked in the app (withdrawing = closing the account).
 */
export const REVOKE_STEPS: Readonly<Record<string, readonly RevokeStep[]>> = {
  camera: ['face_data'],
  biometric: ['face_data', 'voice_data'],
  microphone: ['voice_data'],
  portal_linking: ['portal_unlink'],
  marketing: ['marketing_stop'],
  notifications: [],
  health_data: [],
  analytics: [],
};

export function stepsFor(type: string): readonly RevokeStep[] {
  return REVOKE_STEPS[type] ?? [];
}

/** Revoke handling must finish within this (FR-ONB-03). */
export const DEADLINE_MS = 24 * 60 * 60 * 1000;

/**
 * Cloud Storage prefixes holding a person's media (reserved: anything that
 * stores such media must write under these, D-76).
 */
export const mediaPrefixes = {
  /** Raw selfie photos or video (16.3: deleted immediately on revoke). */
  selfies: (uid: string) => `selfies/${uid}/`,
  /** Approved portraits (from a selfie) and frame sets (D-64, T-AVT-08d). */
  avatars: (uid: string) => `avatars/${uid}/`,
  /** Raw voice samples and raw consent audio (16.3). */
  voiceSamples: (uid: string) => `voice_samples/${uid}/`,
};

/** Deletes every file under a prefix; returns how many were deleted. */
export interface MediaFiles {
  deletePrefix(prefix: string): Promise<number>;
}

/**
 * The project's default bucket, or MEDIA_BUCKET when the media lives in a
 * separate one.
 */
export class CloudStorageMediaFiles implements MediaFiles {
  async deletePrefix(prefix: string): Promise<number> {
    const name = process.env.MEDIA_BUCKET;
    const bucket = name ? getStorage().bucket(name) : getStorage().bucket();
    const [files] = await bucket.getFiles({ prefix });
    let deleted = 0;
    for (const f of files) {
      try {
        await f.delete();
        deleted++;
      } catch (e) {
        // Already gone (a parallel run): fine, it's what we wanted.
        if ((e as { code?: number }).code !== 404) throw e;
      }
    }
    return deleted;
  }
}

/**
 * Counts reported in the audit entry. Numbers only (and the step list).
 */
export type RevokeCounts = {
  media_files_deleted: number;
  avatar_reset: number;
  voices_deleted: number;
  voice_consents_revoked: number;
  portal_links_removed: number;
  portal_events_deleted: number;
  marketing_suppressed: number;
  vendor_requests_queued: number;
};

export const zero = (): RevokeCounts => ({
  media_files_deleted: 0,
  avatar_reset: 0,
  voices_deleted: 0,
  voice_consents_revoked: 0,
  portal_links_removed: 0,
  portal_events_deleted: 0,
  marketing_suppressed: 0,
  vendor_requests_queued: 0,
});

const total = (c: RevokeCounts) =>
  Object.values(c).reduce((a, b) => a + b, 0);

/**
 * A vendor-side action we owe (vendor_requests/{id}, server-only). No vendor
 * is connected yet (T-AVT-03, T-VOC-03, T-PRT, email provider), so nothing
 * is called: the record is the queue the vendor adapter will drain, calling
 * the vendor's API and logging its confirmation (FR-SET-03, 16.3). The id
 * is fixed per uid + kind + vendor reference, so retries queue it once.
 */
export type VendorRequestKind =
  | 'avatar_model_delete'
  | 'voice_model_delete'
  | 'portal_unlink'
  | 'marketing_unsubscribe';

async function queueVendorRequest(
  uid: string,
  kind: VendorRequestKind,
  vendor: string,
  vendorRef: string,
  source: string,
): Promise<number> {
  const hash = createHash('sha256')
    .update(`${vendor}:${vendorRef}`)
    .digest('hex')
    .slice(0, 16);
  const now = Timestamp.now();
  try {
    await getFirestore()
      .doc(`vendor_requests/${kind}_${uid}_${hash}`)
      .create({
        uid,
        kind,
        vendor,
        vendor_ref: vendorRef,
        source,
        status: 'pending',
        requested_at: now,
        due_by: Timestamp.fromMillis(now.toMillis() + DEADLINE_MS),
        created_at: now,
        updated_at: now,
        schema_version: 1,
      });
    return 1;
  } catch (e) {
    if ((e as { code?: number }).code === 6) return 0; // already queued
    throw e;
  }
}

/** Server-only avatar fields that point at made-for-you (face) data. */
const MADE_FOR_YOU_FIELDS = [
  'frames_version',
  'options',
  'vendor',
  'vendor_avatar_id',
  'thumbnail_urls',
];

/**
 * Removes a person's face data: raw selfies, every portrait and frame set
 * (`avatars/{uid}/`), queues the vendor copy's deletion, and puts the
 * avatar back to a ready-made coach (name and background stay). Shared by
 * consent revoke handling (D-76) and "Delete my avatar" (FR-SET-03, D-78);
 * [source] says which (`consent_revoked:{id}`, `delete_my_avatar`) on the
 * vendor request. Idempotent.
 */
export async function deleteFaceData(
  uid: string,
  source: string,
  files: MediaFiles,
  c: RevokeCounts = zero(),
): Promise<RevokeCounts> {
  await faceData(uid, source, files, c);
  return c;
}

async function faceData(
  uid: string,
  source: string,
  files: MediaFiles,
  c: RevokeCounts,
) {
  c.media_files_deleted += await files.deletePrefix(mediaPrefixes.selfies(uid));
  // Every frame set and portrait: we can't tell which ones came from a
  // selfie, so all made-for-you media goes (conservative, D-76).
  c.media_files_deleted += await files.deletePrefix(mediaPrefixes.avatars(uid));

  const ref = getFirestore().doc(`users/${uid}/avatar/current`);
  const snap = await ref.get();
  if (!snap.exists) return;
  const d = snap.data() ?? {};
  const vendorId = d.vendor_avatar_id;
  if (typeof vendorId === 'string' && vendorId) {
    c.vendor_requests_queued += await queueVendorRequest(
      uid,
      'avatar_model_delete',
      String(d.vendor ?? 'unknown'),
      vendorId,
      source,
    );
  }
  const madeForYou =
    (d.source !== undefined && d.source !== 'default') ||
    d.type === 'photoreal' ||
    MADE_FOR_YOU_FIELDS.some((f) => d[f] !== undefined);
  if (!madeForYou) return;
  // Back to a ready-made coach; the person's coach name and background
  // stay (they are not face data).
  const update: Record<string, unknown> = {
    source: 'default',
    raw_media_retained: false,
    updated_at: FieldValue.serverTimestamp(),
  };
  if (d.type === 'photoreal') update.type = '3d_adult';
  for (const f of MADE_FOR_YOU_FIELDS) update[f] = FieldValue.delete();
  await ref.update(update);
  c.avatar_reset += 1;
}

async function voiceData(
  uid: string,
  consentId: string,
  files: MediaFiles,
  c: RevokeCounts,
) {
  const db = getFirestore();
  c.media_files_deleted += await files.deletePrefix(
    mediaPrefixes.voiceSamples(uid),
  );

  // Every cloned voice (self, loved one); library voices are not personal.
  const voices = await db.collection(`users/${uid}/voices`).get();
  for (const v of voices.docs) {
    if (v.get('kind') === 'library') continue;
    const vendorId = v.get('vendor_voice_id');
    if (typeof vendorId === 'string' && vendorId) {
      c.vendor_requests_queued += await queueVendorRequest(
        uid,
        'voice_model_delete',
        String(v.get('vendor') ?? 'unknown'),
        vendorId,
        `consent_revoked:${consentId}`,
      );
    }
    await v.ref.delete();
    c.voices_deleted += 1;
  }

  // Voice consent records stay as legal evidence (hash and record, 16.3),
  // marked revoked.
  const consents = await db
    .collection('voice_consents')
    .where('account_uid', '==', uid)
    .get();
  for (const vc of consents.docs) {
    if (vc.get('status') === 'revoked') continue;
    await vc.ref.update({
      status: 'revoked',
      revoked_at: FieldValue.serverTimestamp(),
      revoked_by: 'account_holder',
      updated_at: FieldValue.serverTimestamp(),
    });
    c.voice_consents_revoked += 1;
  }
}

async function deleteAll(refs: DocumentReference[]) {
  const db = getFirestore();
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    for (const r of refs.slice(i, i + 400)) batch.delete(r);
    await batch.commit();
  }
}

async function portalUnlink(uid: string, consentId: string, c: RevokeCounts) {
  const db = getFirestore();
  const links = await db.collection(`users/${uid}/portal_link`).get();
  for (const l of links.docs) {
    const ref = l.get('tagmango_customer_ref');
    if (typeof ref === 'string' && ref) {
      c.vendor_requests_queued += await queueVendorRequest(
        uid,
        'portal_unlink',
        'tagmango',
        ref,
        `consent_revoked:${consentId}`,
      );
    }
  }
  await deleteAll(links.docs.map((d) => d.ref));
  c.portal_links_removed += links.size;
  // 16.3 "unlinked and anonymized": nothing is kept under the person, so
  // the events are deleted (D-76 asks whether de-identified counts are
  // wanted instead).
  const events = await db.collection(`users/${uid}/portal_events`).get();
  await deleteAll(events.docs.map((d) => d.ref));
  c.portal_events_deleted += events.size;
}

async function marketingStop(
  uid: string,
  consentId: string,
  c: RevokeCounts,
) {
  const ref = getFirestore().doc(`marketing_suppressions/${uid}`);
  const snap = await ref.get();
  if (snap.get('suppressed') !== true) {
    await ref.set(
      {
        uid,
        suppressed: true,
        since: FieldValue.serverTimestamp(),
        source: `consent_revoked:${consentId}`,
        updated_at: FieldValue.serverTimestamp(),
        schema_version: 1,
        ...(snap.exists ? {} : { created_at: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );
    c.marketing_suppressed += 1;
  }
  // Queued when this revocation suppressed marketing (or on its retry): a
  // repeated revoke while already suppressed adds nothing; a revoke after a
  // new grant asks the provider again.
  const ours = snap.get('source') === `consent_revoked:${consentId}`;
  if (c.marketing_suppressed > 0 || ours) {
    c.vendor_requests_queued += await queueVendorRequest(
      uid,
      'marketing_unsubscribe',
      'email_provider',
      consentId,
      `consent_revoked:${consentId}`,
    );
  }
}

/**
 * A new marketing grant lifts the suppression. Nothing deleted on an
 * earlier revoke is ever restored by a grant.
 */
export async function liftMarketingSuppression(uid: string, consentId: string) {
  const ref = getFirestore().doc(`marketing_suppressions/${uid}`);
  const snap = await ref.get();
  if (!snap.exists || snap.get('suppressed') !== true) return;
  await ref.update({
    suppressed: false,
    source: `consent_granted:${consentId}`,
    updated_at: FieldValue.serverTimestamp(),
  });
}

export async function runSteps(
  uid: string,
  consentId: string,
  steps: readonly RevokeStep[],
  files: MediaFiles,
): Promise<RevokeCounts> {
  const c = zero();
  for (const s of steps) {
    switch (s) {
      case 'face_data':
        await faceData(uid, `consent_revoked:${consentId}`, files, c);
        break;
      case 'voice_data':
        await voiceData(uid, consentId, files, c);
        break;
      case 'portal_unlink':
        await portalUnlink(uid, consentId, c);
        break;
      case 'marketing_stop':
        await marketingStop(uid, consentId, c);
        break;
    }
  }
  return c;
}

export const taskId = (uid: string, consentId: string) =>
  `${uid}_${consentId}`;

/**
 * Creates the task for a revocation (once) and runs it. A failed step is
 * recorded on the task (not thrown) and the sweep retries it.
 */
export async function handleRevocation(
  uid: string,
  consentId: string,
  type: string,
  log: AuditLog,
  files: MediaFiles,
): Promise<void> {
  const ref = getFirestore().doc(`consent_revocations/${taskId(uid, consentId)}`);
  const now = Timestamp.now();
  try {
    await ref.create({
      uid,
      consent_id: consentId,
      type,
      steps: [...stepsFor(type)],
      status: 'pending',
      attempts: 0,
      requested_at: now,
      due_by: Timestamp.fromMillis(now.toMillis() + DEADLINE_MS),
      created_at: now,
      updated_at: now,
      schema_version: 1,
    });
  } catch (e) {
    if ((e as { code?: number }).code !== 6) throw e; // exists: a retry
  }
  await runTask(ref, log, files);
}

/**
 * Runs one task if it isn't done. With [followUp], a done task is run once
 * more (the sweep's late-write check); it writes an audit entry only if it
 * removed something.
 */
export async function runTask(
  ref: DocumentReference,
  log: AuditLog,
  files: MediaFiles,
  { followUp = false }: { followUp?: boolean } = {},
): Promise<'done' | 'failed' | 'skipped'> {
  const snap = await ref.get();
  if (!snap.exists) return 'skipped';
  const t = snap.data()!;
  if (t.status === 'done' && !followUp) return 'skipped';
  if (followUp && t.followed_up === true) return 'skipped';
  const uid = String(t.uid);
  const consentId = String(t.consent_id);
  const type = String(t.type);
  const steps = stepsFor(type);
  const attempt = Number(t.attempts ?? 0) + 1;
  try {
    if (followUp && !(await stillRevoked(uid, type, consentId))) {
      // Granted again since: data made after the new grant is theirs to keep.
      await ref.update({ followed_up: true, updated_at: Timestamp.now() });
      return 'skipped';
    }
    const counts = await runSteps(uid, consentId, steps, files);
    if (followUp) {
      await ref.update({ followed_up: true, updated_at: Timestamp.now() });
      if (total(counts) > 0) {
        await log.append(`consent_revoke_followup_${uid}_${consentId}`, {
          actor: 'system',
          action: 'consent.revoke_followup',
          target: `users/${uid}/consents/${consentId}`,
          details: { uid, consent_id: consentId, type, ...counts },
        });
      }
      return 'done';
    }
    await ref.update({
      status: 'done',
      attempts: attempt,
      counts,
      completed_at: Timestamp.now(),
      updated_at: Timestamp.now(),
      last_error: FieldValue.delete(),
    });
    await log.append(`consent_revoke_handled_${uid}_${consentId}`, {
      actor: 'system',
      action: 'consent.revoke_handled',
      target: `users/${uid}/consents/${consentId}`,
      details: {
        uid,
        consent_id: consentId,
        type,
        steps: steps.length ? steps.join(',') : 'none_server_side',
        attempt,
        ...counts,
      },
    });
    return 'done';
  } catch (e) {
    // The error code only: a message could carry paths or content.
    const code = String((e as { code?: unknown }).code ?? 'unknown');
    await ref.update({
      status: followUp ? t.status : 'failed',
      attempts: attempt,
      last_error: code,
      updated_at: Timestamp.now(),
    });
    console.error('consent revoke handling failed', {
      task: ref.id,
      type,
      attempt,
      code,
    });
    return 'failed';
  }
}

/** True when the latest record of [type] is still a revocation. */
async function stillRevoked(uid: string, type: string, consentId: string) {
  const snap = await getFirestore()
    .collection(`users/${uid}/consents`)
    .where('type', '==', type)
    .get();
  let latest: { id: string; at: number; granted: boolean } | undefined;
  for (const d of snap.docs) {
    const at = (d.get('created_at') as Timestamp | undefined)?.toMillis() ?? 0;
    if (!latest || at >= latest.at) {
      latest = { id: d.id, at, granted: d.get('granted') === true };
    }
  }
  return latest === undefined || !latest.granted || latest.id === consentId;
}

/**
 * The sweep (hourly): retries every task that isn't done, and runs each
 * task finished in the last 24 hours once more, so data written by a job
 * already running at revoke time is removed too. Logs any task past its
 * 24-hour deadline (alerting on that log line is set up with T-FND-10).
 */
export async function sweep(
  log: AuditLog,
  files: MediaFiles,
  now: number = Date.now(),
) {
  const db = getFirestore();
  const result = { retried: 0, followed_up: 0, failed: 0, overdue: 0 };
  const open = await db
    .collection('consent_revocations')
    .where('status', 'in', ['pending', 'failed'])
    .get();
  for (const d of open.docs) {
    const r = await runTask(d.ref, log, files);
    result.retried++;
    if (r === 'failed') {
      result.failed++;
      const due = (d.get('due_by') as Timestamp | undefined)?.toMillis() ?? 0;
      if (due < now) {
        result.overdue++;
        console.error('consent revoke handling overdue', { task: d.id });
      }
    }
  }
  const recent = await db
    .collection('consent_revocations')
    .where('completed_at', '>=', Timestamp.fromMillis(now - DEADLINE_MS))
    .get();
  for (const d of recent.docs) {
    if (d.get('followed_up') === true || stepsFor(String(d.get('type'))).length === 0) {
      continue;
    }
    // Leave at least an hour for in-flight jobs (media jobs take minutes).
    const done = (d.get('completed_at') as Timestamp).toMillis();
    if (now - done < 60 * 60 * 1000) continue;
    if ((await runTask(d.ref, log, files, { followUp: true })) === 'done') {
      result.followed_up++;
    }
  }
  return result;
}
