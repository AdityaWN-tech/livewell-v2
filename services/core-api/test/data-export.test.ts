import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { strFromU8, unzipSync } from 'fflate';
import { beforeAll, describe, expect, it } from 'vitest';

import { EXPORTED_USER_COLLECTIONS } from '../src/account/export-collections.js';

// Runs inside `firebase emulators:exec --only auth,firestore,functions,storage`:
// the real callables and the real onDataExportRequested trigger.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell', storageBucket: 'demo-livewell.appspot.com' });
});

const db = () => getFirestore();
const bucket = () => getStorage().bucket();
const fnBase = 'http://127.0.0.1:5001/demo-livewell/us-central1';

async function newUser(): Promise<{ uid: string; idToken: string }> {
  const res = await fetch(
    'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake',
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: `exp-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`,
        password: 'walk-after-lunch',
        returnSecureToken: true,
      }),
    },
  );
  const body = (await res.json()) as { localId: string; idToken: string };
  return { uid: body.localId, idToken: body.idToken };
}

async function call(name: string, idToken?: string, data: object = {}) {
  const res = await fetch(`${fnBase}/${name}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(idToken ? { authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return { status: res.status, body: (await res.json()) as Record<string, any> };
}

const meta = () => ({ created_at: Timestamp.now(), updated_at: Timestamp.now(), schema_version: 1 });

/** One document in every exported collection, each carrying [marker]. */
async function seedEverything(uid: string, marker: string) {
  await db().doc(`users/${uid}`).set({
    display_name: `Name ${marker}`,
    age_confirmed: true,
    why_statement: `Why ${marker}`,
    ed_safe_mode: false,
    ...meta(),
  });
  for (const name of EXPORTED_USER_COLLECTIONS) {
    await db().doc(`users/${uid}/${name}/d1`).set({
      note: `${name} ${marker}`,
      vendor_voice_id: `vendor-${marker}`,
      matched_email_hash: `sha256:${marker}`,
      ...meta(),
    });
  }
  await bucket().file(`avatars/${uid}/v1/neutral@2x.webp`).save(Buffer.from('img'), {
    contentType: 'image/webp',
  });
}

async function waitForStatus(uid: string, jobId: string, timeoutMs = 25_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const snap = await db().doc(`users/${uid}/data_exports/${jobId}`).get();
    const status = snap.get('status');
    if (status && status !== 'preparing') return snap;
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error('export never finished');
}

async function auditFor(uid: string) {
  const snap = await db().collection('audit_log').where('actor', '==', uid).get();
  // The seeded consent record gets its own audit entry (onConsentCreated).
  return snap.docs.map((d) => d.data()).filter((d) => String(d.action).startsWith('data_export.'));
}

describe('data export (FR-SET-02, T-CMP-03)', () => {
  it('refuses anyone who is not signed in', async () => {
    expect((await call('requestDataExport')).status).toBe(401);
    expect((await call('getDataExportLink', undefined, { jobId: 'x' })).status).toBe(401);
  });

  it('refuses an account that never passed the 18+ gate', async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}`).set({ display_name: 'Kid', ...meta() });
    const r = await call('requestDataExport', idToken);
    expect(r.status).toBe(400);
    expect(r.body.error.status).toBe('FAILED_PRECONDITION');
    const none = await call('requestDataExport', (await newUser()).idToken);
    expect(none.status).toBe(400);
  });

  it('exports every listed collection, only mine, without internal fields; rate-limited; logged without content', async () => {
    const me = await newUser();
    const other = await newUser();
    await seedEverything(me.uid, 'MINE7');
    await seedEverything(other.uid, 'THEIRS9');

    const r = await call('requestDataExport', me.idToken);
    expect(r.status).toBe(200);
    const jobId = r.body.result.jobId as string;

    const job = await waitForStatus(me.uid, jobId);
    expect(job.get('status')).toBe('ready');
    const readyAt = (job.get('ready_at') as Timestamp).toMillis();
    const expiresAt = (job.get('expires_at') as Timestamp).toMillis();
    expect(expiresAt - readyAt).toBe(7 * 24 * 60 * 60 * 1000);
    for (const name of EXPORTED_USER_COLLECTIONS) expect(job.get('counts')[name]).toBe(1);

    // The zip, its metadata and its contents.
    const file = bucket().file(`exports/${me.uid}/${jobId}.zip`);
    const [md] = await file.getMetadata();
    expect(md.contentType).toBe('application/zip');
    expect(md.metadata?.expires_at).toBe(new Date(expiresAt).toISOString());
    expect(md.contentDisposition).toMatch(/^attachment; filename="livewell-data-\d{4}-\d{2}-\d{2}\.zip"$/);
    const [zip] = await file.download();
    const files = unzipSync(new Uint8Array(zip));
    expect(Object.keys(files).sort()).toEqual([
      'livewell-data/README.txt',
      'livewell-data/data.json',
      'livewell-data/summary.pdf',
    ]);
    const json = strFromU8(files['livewell-data/data.json']!);
    const data = JSON.parse(json);
    expect(data.uid).toBe(me.uid);
    expect(data.profile.why_statement).toBe('Why MINE7');
    for (const name of EXPORTED_USER_COLLECTIONS) {
      expect(data.collections[name]).toEqual([
        expect.objectContaining({ id: 'd1', data: expect.objectContaining({ note: `${name} MINE7` }) }),
      ]);
    }
    expect(data.storage_files.map((f: { path: string }) => f.path)).toEqual([
      `avatars/${me.uid}/v1/neutral@2x.webp`,
    ]);
    // Never another person's data, never internal fields.
    expect(json).not.toContain('THEIRS9');
    expect(json).not.toContain(other.uid);
    expect(json).not.toMatch(/"vendor_voice_id"|"matched_email_hash"|"ed_safe_mode"|vendor-MINE7|sha256:MINE7/);
    expect(strFromU8(files['livewell-data/summary.pdf']!).startsWith('%PDF-1.4')).toBe(true);

    // One export a day.
    const again = await call('requestDataExport', me.idToken);
    expect(again.status).toBe(429);
    expect(again.body.error.status).toBe('RESOURCE_EXHAUSTED');
    expect(again.body.error.details.job_id).toBe(jobId);
    // ... per person: someone else can still ask.
    const theirs = await call('requestDataExport', other.idToken);
    expect(theirs.status).toBe(200);

    // A short-lived download link, for the owner only.
    const link = await call('getDataExportLink', me.idToken, { jobId });
    expect(link.status).toBe(200);
    expect(link.body.result.url).toContain(encodeURIComponent(`exports/${me.uid}/${jobId}.zip`));
    const linkExpires = Date.parse(link.body.result.expiresAt);
    expect(linkExpires - Date.now()).toBeLessThanOrEqual(15 * 60 * 1000);
    expect((await call('getDataExportLink', other.idToken, { jobId })).status).toBe(404);
    expect((await call('getDataExportLink', me.idToken, { jobId: '../x' })).status).toBe(400);

    // Audit: requested, ready, link issued; ids and counts only.
    const audit = await auditFor(me.uid);
    const actions = audit.map((a) => a.action).sort();
    expect(actions).toEqual(['data_export.link_issued', 'data_export.ready', 'data_export.requested']);
    const ready = audit.find((a) => a.action === 'data_export.ready')!;
    expect(ready.details).toMatchObject({
      documents: EXPORTED_USER_COLLECTIONS.length + 1,
      collections: EXPORTED_USER_COLLECTIONS.length,
      storage_files: 1,
      unlisted_collections: 0,
    });
    expect(JSON.stringify(audit)).not.toMatch(/MINE7|Why /);
  });

  it('a failed or day-old export does not block a new one; an expired one gives no link', async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}`).set({ age_confirmed: true, ...meta() });
    const hourAgo = Timestamp.fromMillis(Date.now() - 61 * 60 * 1000);
    // Server-side state written directly; the trigger ignores non-"preparing" jobs.
    await db().doc(`users/${uid}/data_exports/old1`).set({
      status: 'failed', created_at: Timestamp.now(), updated_at: Timestamp.now(), schema_version: 1,
    });
    await db().doc(`users/${uid}/data_exports/old2`).set({
      status: 'ready', created_at: Timestamp.fromMillis(Date.now() - 25 * 3600_000),
      updated_at: hourAgo, schema_version: 1, expires_at: Timestamp.fromMillis(Date.now() - 1000),
    });
    expect((await call('getDataExportLink', idToken, { jobId: 'old2' })).status).toBe(400);
    expect((await call('getDataExportLink', idToken, { jobId: 'old1' })).status).toBe(404);
    const r = await call('requestDataExport', idToken);
    expect(r.status).toBe(200);
    expect((await waitForStatus(uid, r.body.result.jobId)).get('status')).toBe('ready');
  });

  it('deleting the account deletes waiting export files', async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}`).set({ age_confirmed: true, ...meta() });
    const r = await call('requestDataExport', idToken);
    const jobId = r.body.result.jobId as string;
    await waitForStatus(uid, jobId);
    const file = bucket().file(`exports/${uid}/${jobId}.zip`);
    expect((await file.exists())[0]).toBe(true);
    expect((await call('deleteAccount', idToken)).status).toBe(200);
    expect((await file.exists())[0]).toBe(false);
  });
});
