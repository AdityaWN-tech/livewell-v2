import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { beforeAll, describe, expect, it } from 'vitest';

// Runs inside `firebase emulators:exec --only auth,firestore,functions,storage`:
// the callables are the real deployed-to-emulator functions, called over
// HTTP with an Auth-emulator ID token, exactly as the app calls them.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell', storageBucket: 'demo-livewell.appspot.com' });
});

const db = () => getFirestore();
const project = 'demo-livewell';
const fnBase = `http://127.0.0.1:5001/${project}/us-central1`;

async function newUser(): Promise<{ uid: string; idToken: string }> {
  const res = await fetch(
    'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake',
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: `del-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`,
        password: 'walk-after-lunch',
        returnSecureToken: true,
      }),
    },
  );
  const body = (await res.json()) as { localId: string; idToken: string };
  return { uid: body.localId, idToken: body.idToken };
}

async function call(name: string, idToken?: string) {
  const res = await fetch(`${fnBase}/${name}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(idToken ? { authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data: {} }),
  });
  return { status: res.status, body: (await res.json()) as Record<string, unknown> };
}

const meta = () => ({ created_at: Timestamp.now(), updated_at: Timestamp.now(), schema_version: 1 });

async function auditFor(uid: string, action: string) {
  const snap = await db().collection('audit_log').where('actor', '==', uid).get();
  return snap.docs.map((d) => d.data()).filter((d) => d.action === action);
}

describe('deletions (FR-SET-02/03)', () => {
  it('refuses anyone who is not signed in', async () => {
    for (const name of ['deleteAvatar', 'deleteVoice', 'deleteAccount']) {
      const r = await call(name);
      expect(r.status).toBe(401);
    }
  });

  const bucket = () => getStorage().bucket();
  const put = (path: string) => bucket().file(path).save(Buffer.from('x'));
  const exists = async (path: string) => (await bucket().file(path).exists())[0];

  it('Delete my avatar: portrait, frames, selfie and vendor copy go; a ready-made coach takes over; logged (T-AVT-05, D-78)', async () => {
    const { uid, idToken } = await newUser();
    const other = await newUser();
    await db().doc(`users/${uid}/avatar/current`).set({
      type: '3d_adult',
      source: 'selfie',
      coach_id: 'green_hijab',
      coach_name: 'Maya',
      background: 2,
      frames_version: 3,
      options: { outfit: 'green_knit' },
      vendor: 'acme_avatar',
      vendor_avatar_id: 'va-123',
      thumbnail_urls: { neutral: 'avatars/x/3/neutral_thumb.png' },
      raw_media_retained: false,
      ...meta(),
    });
    await put(`avatars/${uid}/portraits/p1.png`);
    await put(`avatars/${uid}/3/avatar_frames.json`);
    await put(`avatars/${uid}/3/neutral@2x.webp`);
    await put(`selfies/${uid}/raw.jpg`);
    await put(`avatars/${other.uid}/portraits/keep.png`);

    const r = await call('deleteAvatar', idToken);
    expect(r.status).toBe(200);
    expect(r.body.result).toEqual({ deleted: true, reset: true });

    // Every file in Cloud Storage is gone; nobody else's is touched.
    expect(await exists(`avatars/${uid}/portraits/p1.png`)).toBe(false);
    expect(await exists(`avatars/${uid}/3/avatar_frames.json`)).toBe(false);
    expect(await exists(`avatars/${uid}/3/neutral@2x.webp`)).toBe(false);
    expect(await exists(`selfies/${uid}/raw.jpg`)).toBe(false);
    expect(await exists(`avatars/${other.uid}/portraits/keep.png`)).toBe(true);

    // Back to the ready-made coach; name and background stay.
    const avatar = (await db().doc(`users/${uid}/avatar/current`).get()).data()!;
    expect(avatar.source).toBe('default');
    expect(avatar.coach_id).toBe('green_hijab');
    expect(avatar.coach_name).toBe('Maya');
    expect(avatar.background).toBe(2);
    for (const f of ['frames_version', 'options', 'vendor', 'vendor_avatar_id', 'thumbnail_urls']) {
      expect(avatar[f]).toBeUndefined();
    }

    // The vendor copy is queued for deletion (drained by the adapter, T-AVT-03).
    const vendor = await db().collection('vendor_requests').where('uid', '==', uid).get();
    expect(vendor.docs.map((d) => d.data())).toEqual([
      expect.objectContaining({
        kind: 'avatar_model_delete',
        vendor: 'acme_avatar',
        vendor_ref: 'va-123',
        source: 'delete_my_avatar',
        status: 'pending',
      }),
    ]);

    // One audit entry, counts only: no name, no paths.
    const audit = await auditFor(uid, 'avatar.deleted');
    expect(audit).toHaveLength(1);
    expect(audit[0].details).toEqual({
      existed: true,
      media_files_deleted: 4,
      avatar_reset: 1,
      vendor_requests_queued: 1,
    });
    expect(JSON.stringify(audit[0])).not.toMatch(/Maya|va-123|\.png|\.jpg/);
  });

  it('Delete my avatar twice, or with no avatar: nothing fails, each is logged', async () => {
    const { uid, idToken } = await newUser();
    expect((await call('deleteAvatar', idToken)).status).toBe(200);
    await db().doc(`users/${uid}/avatar/current`).set({
      type: '3d_adult', source: 'default', coach_id: 'brown_hair', background: 0, raw_media_retained: false, ...meta(),
    });
    const r = await call('deleteAvatar', idToken);
    expect(r.status).toBe(200);
    expect(r.body.result).toEqual({ deleted: true, reset: false });
    // A ready-made coach is left as it is.
    expect((await db().doc(`users/${uid}/avatar/current`).get()).get('coach_id')).toBe('brown_hair');
    const audit = await auditFor(uid, 'avatar.deleted');
    expect(audit).toHaveLength(2);
    expect(audit.map((a) => a.details.existed).sort()).toEqual([false, true]);
  });

  it('Delete my voice: removes every voice and logs the count', async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}/voices/lw-warm`).set({ kind: 'library', status: 'inactive', ...meta() });
    await db().doc(`users/${uid}/voices/lw-clear`).set({ kind: 'library', status: 'active', ...meta() });
    const r = await call('deleteVoice', idToken);
    expect(r.status).toBe(200);
    expect((await db().collection(`users/${uid}/voices`).get()).size).toBe(0);
    const audit = await auditFor(uid, 'voice.deleted');
    expect(audit[0].details).toEqual({ count: 2, cloned: 0 });
  });

  it('Delete my account: profile, sub-collections and sign-in all gone; logged', async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}`).set({ display_name: 'Priya', age_confirmed: true, ...meta() });
    await db().doc(`users/${uid}/checkins/2026-10-15`).set({ mood: 4, source: 'app', gentle_day: false, ...meta() });
    await db().doc(`users/${uid}/reflections/2026-10-15`).set({ text: 'A walk', ...meta() });
    const other = await newUser();
    await db().doc(`users/${other.uid}`).set({ display_name: 'Other', ...meta() });

    const r = await call('deleteAccount', idToken);
    expect(r.status).toBe(200);
    expect((await db().doc(`users/${uid}`).get()).exists).toBe(false);
    expect((await db().collection(`users/${uid}/checkins`).get()).size).toBe(0);
    expect((await db().collection(`users/${uid}/reflections`).get()).size).toBe(0);
    await expect(getAuth().getUser(uid)).rejects.toThrow();
    // Nobody else's data is touched.
    expect((await db().doc(`users/${other.uid}`).get()).exists).toBe(true);
    const audit = await auditFor(uid, 'account.deleted');
    expect(audit).toHaveLength(1);
    // No health content in the log (spec 16.3).
    expect(JSON.stringify(audit[0])).not.toMatch(/Priya|walk|mood/i);
  });
});
