import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { beforeAll, describe, expect, it } from 'vitest';

import { FirestoreAuditLog } from '../src/audit/audit-log.js';
import {
  CloudStorageMediaFiles,
  REVOKE_STEPS,
  runTask,
  stepsFor,
  sweep,
} from '../src/consents/revoke-handling.js';

// Runs inside `firebase emulators:exec --only auth,firestore,functions,storage`
// (npm test): the real onConsentCreated trigger runs in the functions
// emulator and deletes from the Storage emulator. FR-ONB-03 → spec 16.3, D-76.
const PROJECT = 'demo-livewell';
beforeAll(() => {
  initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
});

const db = () => getFirestore();
const bucket = () => getStorage().bucket();
const log = new FirestoreAuditLog();
const files = new CloudStorageMediaFiles();

let n = 0;
const newUid = () => `rv${Date.now().toString(36)}${n++}`;
const meta = () => ({
  created_at: Timestamp.now(),
  updated_at: Timestamp.now(),
  schema_version: 1,
});

async function waitFor<T>(
  probe: () => Promise<T | undefined>,
  what: string,
  timeoutMs = 20_000,
): Promise<T> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const v = await probe();
    if (v !== undefined) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timed out waiting for ${what}`);
}

const waitForDoc = (path: string) =>
  waitFor(async () => {
    const s = await db().doc(path).get();
    return s.exists ? s.data()! : undefined;
  }, path);

/** Adds a consent record as the app does; returns its id. */
async function decide(uid: string, type: string, granted: boolean) {
  const ref = await db().collection(`users/${uid}/consents`).add({
    type,
    doc_version: `${type}-0.1-draft`,
    granted,
    app_version: '1.0.0',
    ...meta(),
  });
  // Strictly increasing created_at between records.
  await new Promise((r) => setTimeout(r, 5));
  return ref.id;
}

/** Revokes and waits for the handling's audit entry. */
async function revoke(uid: string, type: string) {
  const id = await decide(uid, type, false);
  const audit = await waitForDoc(`audit_log/consent_revoke_handled_${uid}_${id}`);
  return { id, audit, details: audit.details as Record<string, unknown> };
}

async function put(path: string) {
  await bucket().file(path).save(Buffer.from('x'));
}
async function exists(path: string) {
  return (await bucket().file(path).exists())[0];
}
async function vendorRequests(uid: string) {
  const s = await db().collection('vendor_requests').where('uid', '==', uid).get();
  return s.docs.map((d) => d.data());
}

const ZERO = {
  media_files_deleted: 0,
  avatar_reset: 0,
  voices_deleted: 0,
  voice_consents_revoked: 0,
  portal_links_removed: 0,
  portal_events_deleted: 0,
  marketing_suppressed: 0,
  vendor_requests_queued: 0,
};

async function seedFaceData(uid: string) {
  await db().doc(`users/${uid}/avatar/current`).set({
    type: '3d_adult',
    source: 'selfie',
    coach_id: 'brown_hair',
    coach_name: 'Sunny',
    background: 2,
    frames_version: 3,
    options: { hair: 'curly' },
    vendor: 'avatar_vendor',
    vendor_avatar_id: 'av_123',
    raw_media_retained: false,
    ...meta(),
  });
  await put(`selfies/${uid}/raw.jpg`);
  await put(`avatars/${uid}/portraits/p1.png`);
  await put(`avatars/${uid}/3/neutral@2x.webp`);
}

async function seedVoiceData(uid: string) {
  await db().doc(`users/${uid}/voices/lw-warm`).set({
    kind: 'library', vendor_voice_id: 'lib', status: 'active', speed: 1, style: 'calm', ...meta(),
  });
  await db().doc(`users/${uid}/voices/clone1`).set({
    kind: 'self_clone', vendor: 'voice_vendor', vendor_voice_id: 'vv_9', status: 'inactive', speed: 1, style: 'calm', ...meta(),
  });
  await db().doc(`voice_consents/vc_${uid}`).set({
    account_uid: uid, status: 'active', consent_audio_hash: 'h', ...meta(),
  });
  await put(`voice_samples/${uid}/s1.wav`);
  await put(`voice_samples/${uid}/consent.wav`);
}

describe('steps per consent type (D-76)', () => {
  it('covers every granular consent type of FR-ONB-03', () => {
    expect(Object.keys(REVOKE_STEPS).sort()).toEqual(
      ['analytics', 'biometric', 'camera', 'health_data', 'marketing',
        'microphone', 'notifications', 'portal_linking'],
    );
    expect(stepsFor('camera')).toEqual(['face_data']);
    expect(stepsFor('biometric')).toEqual(['face_data', 'voice_data']);
    expect(stepsFor('microphone')).toEqual(['voice_data']);
    expect(stepsFor('portal_linking')).toEqual(['portal_unlink']);
    expect(stepsFor('marketing')).toEqual(['marketing_stop']);
    expect(stepsFor('something_new')).toEqual([]);
  });
});

describe('revoke handling (functions + storage emulators)', () => {
  it('camera: selfies, face data and frames deleted; coach reset; vendor deletion queued; audited', async () => {
    const uid = newUid();
    const other = newUid();
    await put(`avatars/${other}/portraits/keep.png`);
    await seedFaceData(uid);
    await decide(uid, 'camera', true);
    const { id, audit, details } = await revoke(uid, 'camera');

    expect(await exists(`selfies/${uid}/raw.jpg`)).toBe(false);
    expect(await exists(`avatars/${uid}/portraits/p1.png`)).toBe(false);
    expect(await exists(`avatars/${uid}/3/neutral@2x.webp`)).toBe(false);
    expect(await exists(`avatars/${other}/portraits/keep.png`)).toBe(true);

    const avatar = (await db().doc(`users/${uid}/avatar/current`).get()).data()!;
    expect(avatar.source).toBe('default');
    expect(avatar.frames_version).toBeUndefined();
    expect(avatar.options).toBeUndefined();
    expect(avatar.vendor_avatar_id).toBeUndefined();
    expect(avatar.coach_name).toBe('Sunny'); // not face data
    expect(avatar.coach_id).toBe('brown_hair');

    const queued = await vendorRequests(uid);
    expect(queued).toHaveLength(1);
    expect(queued[0]).toMatchObject({
      kind: 'avatar_model_delete', vendor: 'avatar_vendor', vendor_ref: 'av_123', status: 'pending',
    });

    expect(audit.actor).toBe('system');
    expect(audit.action).toBe('consent.revoke_handled');
    expect(audit.target).toBe(`users/${uid}/consents/${id}`);
    expect(details).toEqual({
      ...ZERO,
      uid,
      consent_id: id,
      type: 'camera',
      steps: 'face_data',
      attempt: 1,
      media_files_deleted: 3,
      avatar_reset: 1,
      vendor_requests_queued: 1,
    });
    // No content in the audit log (16.3).
    expect(JSON.stringify(audit)).not.toMatch(/Sunny|curly|av_123/);

    const task = await waitForDoc(`consent_revocations/${uid}_${id}`);
    expect(task.status).toBe('done');
    expect((task.completed_at as Timestamp).toMillis())
      .toBeLessThanOrEqual((task.due_by as Timestamp).toMillis());
  });

  it('biometric: face and voice data deleted, voice consent kept as evidence and marked revoked', async () => {
    const uid = newUid();
    await seedFaceData(uid);
    await seedVoiceData(uid);
    const { details } = await revoke(uid, 'biometric');

    expect(await exists(`selfies/${uid}/raw.jpg`)).toBe(false);
    expect(await exists(`voice_samples/${uid}/s1.wav`)).toBe(false);
    expect(await exists(`voice_samples/${uid}/consent.wav`)).toBe(false);
    expect((await db().doc(`users/${uid}/voices/clone1`).get()).exists).toBe(false);
    expect((await db().doc(`users/${uid}/voices/lw-warm`).get()).exists).toBe(true);
    const vc = (await db().doc(`voice_consents/vc_${uid}`).get()).data()!;
    expect(vc.status).toBe('revoked');
    expect(vc.revoked_by).toBe('account_holder');
    expect(vc.consent_audio_hash).toBe('h'); // evidence kept (16.3)
    expect(details).toMatchObject({
      steps: 'face_data,voice_data',
      media_files_deleted: 5,
      avatar_reset: 1,
      voices_deleted: 1,
      voice_consents_revoked: 1,
      vendor_requests_queued: 2,
    });
    const kinds = (await vendorRequests(uid)).map((r) => r.kind).sort();
    expect(kinds).toEqual(['avatar_model_delete', 'voice_model_delete']);
  });

  it('microphone: voice recordings and voice copies deleted; the avatar is untouched', async () => {
    const uid = newUid();
    await seedFaceData(uid);
    await seedVoiceData(uid);
    const { details } = await revoke(uid, 'microphone');

    expect(await exists(`voice_samples/${uid}/s1.wav`)).toBe(false);
    expect((await db().doc(`users/${uid}/voices/clone1`).get()).exists).toBe(false);
    expect(await exists(`selfies/${uid}/raw.jpg`)).toBe(true);
    const avatar = (await db().doc(`users/${uid}/avatar/current`).get()).data()!;
    expect(avatar.source).toBe('selfie');
    expect(details).toMatchObject({
      steps: 'voice_data',
      media_files_deleted: 2,
      voices_deleted: 1,
      avatar_reset: 0,
      vendor_requests_queued: 1,
    });
  });

  it('portal_linking: link removed, portal events deleted, TagMango unlink queued', async () => {
    const uid = newUid();
    await db().doc(`users/${uid}/portal_link/current`).set({
      tagmango_customer_ref: 'tm_42', matched_email_hash: 'e', status: 'linked', ...meta(),
    });
    await db().doc(`users/${uid}/portal_events/e1`).set({ event: 'clicked', offer_id: 'o1', ...meta() });
    await db().doc(`users/${uid}/portal_events/e2`).set({ event: 'order', offer_id: 'o1', value: 10, ...meta() });
    const { details } = await revoke(uid, 'portal_linking');

    expect((await db().collection(`users/${uid}/portal_link`).get()).size).toBe(0);
    expect((await db().collection(`users/${uid}/portal_events`).get()).size).toBe(0);
    expect(details).toMatchObject({
      steps: 'portal_unlink', portal_links_removed: 1, portal_events_deleted: 2, vendor_requests_queued: 1,
    });
    const [q] = await vendorRequests(uid);
    expect(q).toMatchObject({ kind: 'portal_unlink', vendor: 'tagmango', vendor_ref: 'tm_42' });
  });

  it('marketing: sends stopped; a repeat is a no-op; a new grant lifts it; a later revoke stops again', async () => {
    const uid = newUid();
    await decide(uid, 'marketing', true);
    const first = await revoke(uid, 'marketing');
    expect(first.details).toMatchObject({ marketing_suppressed: 1, vendor_requests_queued: 1 });
    let s = (await db().doc(`marketing_suppressions/${uid}`).get()).data()!;
    expect(s.suppressed).toBe(true);

    const again = await revoke(uid, 'marketing');
    expect(again.details).toMatchObject({ ...ZERO, steps: 'marketing_stop' });
    expect(await vendorRequests(uid)).toHaveLength(1);

    await decide(uid, 'marketing', true);
    await waitFor(async () => {
      const d = await db().doc(`marketing_suppressions/${uid}`).get();
      return d.get('suppressed') === false ? true : undefined;
    }, 'suppression lifted');

    const later = await revoke(uid, 'marketing');
    expect(later.details).toMatchObject({ marketing_suppressed: 1, vendor_requests_queued: 1 });
    s = (await db().doc(`marketing_suppressions/${uid}`).get()).data()!;
    expect(s.suppressed).toBe(true);
    expect(await vendorRequests(uid)).toHaveLength(2);
  });

  for (const type of ['notifications', 'health_data', 'analytics']) {
    it(`${type}: no server-held data, still audited`, async () => {
      const uid = newUid();
      const { details } = await revoke(uid, type);
      expect(details).toEqual({
        ...ZERO, uid, consent_id: details.consent_id, type, steps: 'none_server_side', attempt: 1,
      });
    });
  }

  it('a repeated revoke deletes nothing more and changes nothing', async () => {
    const uid = newUid();
    await seedFaceData(uid);
    await revoke(uid, 'camera');
    const avatarBefore = (await db().doc(`users/${uid}/avatar/current`).get()).data()!;
    const { details } = await revoke(uid, 'camera');
    expect(details).toMatchObject({ ...ZERO, steps: 'face_data' });
    const avatarAfter = (await db().doc(`users/${uid}/avatar/current`).get()).data()!;
    expect(avatarAfter.updated_at).toEqual(avatarBefore.updated_at);
    expect(await vendorRequests(uid)).toHaveLength(1);
  });

  it('a retried task (same revocation) is skipped and writes no second entry', async () => {
    const uid = newUid();
    await seedVoiceData(uid);
    const { id } = await revoke(uid, 'microphone');
    const ref = db().doc(`consent_revocations/${uid}_${id}`);
    expect(await runTask(ref, log, files)).toBe('skipped');
    const entries = await db().collection('audit_log')
      .where('target', '==', `users/${uid}/consents/${id}`).get();
    // consent.revoked (the record) + consent.revoke_handled (the handling).
    expect(entries.docs.map((d) => d.get('action')).sort())
      .toEqual(['consent.revoke_handled', 'consent.revoked']);
  });

  it('granting again does not restore deleted data', async () => {
    const uid = newUid();
    await seedFaceData(uid);
    await seedVoiceData(uid);
    await revoke(uid, 'biometric');
    const grant = await decide(uid, 'biometric', true);
    await waitForDoc(`audit_log/consent_${uid}_${grant}`);
    expect(await exists(`selfies/${uid}/raw.jpg`)).toBe(false);
    expect(await exists(`avatars/${uid}/portraits/p1.png`)).toBe(false);
    expect(await exists(`voice_samples/${uid}/s1.wav`)).toBe(false);
    expect((await db().doc(`users/${uid}/voices/clone1`).get()).exists).toBe(false);
    const avatar = (await db().doc(`users/${uid}/avatar/current`).get()).data()!;
    expect(avatar.source).toBe('default');
    expect(avatar.frames_version).toBeUndefined();
    expect((await db().doc(`consent_revocations/${uid}_${grant}`).get()).exists).toBe(false);
  });
});

describe('sweep (hourly retry, D-76)', () => {
  async function task(uid: string, consentId: string, type: string, extra: Record<string, unknown>) {
    const now = Timestamp.now();
    await db().doc(`consent_revocations/${uid}_${consentId}`).set({
      uid, consent_id: consentId, type, steps: stepsFor(type), attempts: 1,
      requested_at: now, due_by: Timestamp.fromMillis(now.toMillis() + 86_400_000),
      ...meta(), ...extra,
    });
  }

  it('retries a failed task, finishes it and audits it', async () => {
    const uid = newUid();
    await seedVoiceData(uid);
    await task(uid, 'c_failed', 'microphone', { status: 'failed', last_error: '14' });
    const r = await sweep(log, files);
    expect(r.retried).toBeGreaterThanOrEqual(1);
    const t = (await db().doc(`consent_revocations/${uid}_c_failed`).get()).data()!;
    expect(t.status).toBe('done');
    expect(t.attempts).toBe(2);
    expect(t.last_error).toBeUndefined();
    expect(await exists(`voice_samples/${uid}/s1.wav`)).toBe(false);
    const audit = await waitForDoc(`audit_log/consent_revoke_handled_${uid}_c_failed`);
    expect(audit.details).toMatchObject({ attempt: 2, voices_deleted: 1 });
  });

  it('re-runs a recent task once to catch late writes, and only while still revoked', async () => {
    const uid = newUid();
    const revoked = await decide(uid, 'camera', false);
    await waitForDoc(`audit_log/consent_revoke_handled_${uid}_${revoked}`);
    // As if done 2 hours ago, then a job that was already running wrote
    // a frame set afterwards.
    const twoHoursAgo = Timestamp.fromMillis(Date.now() - 2 * 3_600_000);
    await db().doc(`consent_revocations/${uid}_${revoked}`).update({ completed_at: twoHoursAgo });
    await put(`avatars/${uid}/4/neutral@2x.webp`);

    await sweep(log, files);
    expect(await exists(`avatars/${uid}/4/neutral@2x.webp`)).toBe(false);
    const f = await waitForDoc(`audit_log/consent_revoke_followup_${uid}_${revoked}`);
    expect(f.details).toMatchObject({ media_files_deleted: 1 });
    expect((await db().doc(`consent_revocations/${uid}_${revoked}`).get()).get('followed_up')).toBe(true);

    // Granted again since: what was made after the new grant stays.
    const uid2 = newUid();
    const r2 = await decide(uid2, 'camera', false);
    await waitForDoc(`audit_log/consent_revoke_handled_${uid2}_${r2}`);
    await db().doc(`consent_revocations/${uid2}_${r2}`).update({ completed_at: twoHoursAgo });
    await decide(uid2, 'camera', true);
    await put(`avatars/${uid2}/1/neutral@2x.webp`);
    await sweep(log, files);
    expect(await exists(`avatars/${uid2}/1/neutral@2x.webp`)).toBe(true);
    expect((await db().doc(`consent_revocations/${uid2}_${r2}`).get()).get('followed_up')).toBe(true);
  });
});
