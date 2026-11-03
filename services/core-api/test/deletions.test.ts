import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { beforeAll, describe, expect, it } from 'vitest';

// Runs inside `firebase emulators:exec --only auth,firestore,functions`:
// the callables are the real deployed-to-emulator functions, called over
// HTTP with an Auth-emulator ID token, exactly as the app calls them.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell' });
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

  it('Delete my avatar: removes it and writes an audit entry', async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}/avatar/current`).set({ type: 'stylized', style_config: {}, ...meta() });
    const r = await call('deleteAvatar', idToken);
    expect(r.status).toBe(200);
    expect((await db().doc(`users/${uid}/avatar/current`).get()).exists).toBe(false);
    const audit = await auditFor(uid, 'avatar.deleted');
    expect(audit).toHaveLength(1);
    expect(audit[0].details).toEqual({ existed: true, vendor_models_deleted: 0 });
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
