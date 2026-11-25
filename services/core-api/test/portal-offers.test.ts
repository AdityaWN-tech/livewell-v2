import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeAll, describe, expect, it } from 'vitest';

// Portal catalog callables (T-PRT-02, D-92) against the Auth, Firestore and
// Functions emulators, called over HTTP with real emulator ID tokens that
// carry the staff custom claims, exactly as the Admin web app calls them.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell' });
});

const db = () => getFirestore();
const project = 'demo-livewell';
const fnBase = `http://127.0.0.1:5001/${project}/us-central1`;
const authBase = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';

interface User {
  uid: string;
  idToken: string;
}

async function rest(path: string, body: unknown) {
  const res = await fetch(`${authBase}/${path}?key=fake`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  return (await res.json()) as { localId: string; idToken: string };
}

/** A user with [claims]; signs in again so the token carries them. */
async function user(claims?: Record<string, unknown>): Promise<User> {
  const email = `staff-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
  const password = 'calm-walk-42';
  const signUp = await rest('accounts:signUp', { email, password, returnSecureToken: true });
  if (!claims) return { uid: signUp.localId, idToken: signUp.idToken };
  await getAuth().setCustomUserClaims(signUp.localId, claims);
  const signIn = await rest('accounts:signInWithPassword', { email, password, returnSecureToken: true });
  return { uid: signUp.localId, idToken: signIn.idToken };
}

const waiver = () => Math.floor(Date.now() / 1000) + 24 * 3600;
const staff = (...roles: string[]) => user({ staff_roles: roles, staff_mfa_waiver_until: waiver() });

async function call(name: string, u: User | undefined, data: unknown = {}) {
  const res = await fetch(`${fnBase}/${name}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(u ? { authorization: `Bearer ${u.idToken}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = (await res.json()) as {
    result?: Record<string, unknown>;
    error?: { status: string; message: string; details?: { reason?: string } };
  };
  return { status: res.status, ...body };
}

const fields = {
  title: 'Gut health in 30 days',
  description: 'A short course from Dr. Gokula.',
  url: 'https://livewell.conciergeconnectedcare.net/web/courses/gut-health',
  offer_type: 'course',
  driver_tags: ['nutrition'],
  topic_tags: ['gut_health'],
  price_display: '$49',
};

async function auditFor(id: string) {
  const snap = await db().collection('audit_log').where('target', '==', `portal_offers/${id}`).get();
  return snap.docs.map((d) => d.data()).sort((a, b) => a.details.rev - b.details.rev);
}

describe('portal offers: who may call (spec 16.2)', () => {
  it('refuses signed-out callers, app users, and staff without MFA', async () => {
    const appUser = await user();
    const noMfa = await user({ staff_roles: ['admin'] });
    for (const name of [
      'adminListPortalOffers',
      'adminCreatePortalOffer',
      'adminUpdatePortalOffer',
      'adminTransitionPortalOffer',
    ]) {
      expect((await call(name, undefined)).status).toBe(401);
      const r = await call(name, appUser, { fields });
      expect(r.status).toBe(403);
      expect(r.error?.details?.reason).toBe('not_staff');
      const m = await call(name, noMfa, { fields });
      expect(m.status).toBe(403);
      expect(m.error?.details?.reason).toBe('mfa_required');
    }
  });

  it('reviewers cannot create; invalid fields are refused', async () => {
    const reviewer = await staff('clinical_reviewer');
    expect((await call('adminCreatePortalOffer', reviewer, { fields })).status).toBe(403);
    const editor = await staff('content_editor');
    const bad = await call('adminCreatePortalOffer', editor, {
      fields: { ...fields, url: 'https://example.com/x' },
    });
    expect(bad.status).toBe(400);
    expect(bad.error?.details?.reason).toBe('invalid');
    const sneaky = await call('adminCreatePortalOffer', editor, {
      fields: { ...fields, active: true, review_status: 'approved' },
    });
    expect(sneaky.status).toBe(400);
  });
});

describe('portal offers: editors publish, reviewers approve (17.4 T-PRT-02)', () => {
  it('create → submit → approve → publish → edit (offline) → archive, all audited', async () => {
    const editor = await staff('content_editor');
    const reviewer = await staff('clinical_reviewer');

    const created = await call('adminCreatePortalOffer', editor, { fields });
    expect(created.status).toBe(200);
    const id = created.result!.id as string;
    let rev = created.result!.rev as number;

    const offer = async () => (await db().doc(`portal_offers/${id}`).get()).data()!;
    expect(await offer()).toMatchObject({ review_status: 'draft', active: false, version: 1, title: fields.title });
    // Staff ids stay out of the client-readable document.
    expect(JSON.stringify(await offer())).not.toContain(editor.uid);
    const flow = (await db().doc(`portal_offer_workflow/${id}`).get()).data()!;
    expect(flow).toMatchObject({ created_by: editor.uid, version_editors: [editor.uid], rev: 1 });

    const t = async (who: User, action: string, expectedRev = rev) =>
      call('adminTransitionPortalOffer', who, { id, expected_rev: expectedRev, action });

    // Publishing before approval is refused.
    let r = await t(editor, 'publish');
    expect(r.status).toBe(400);
    expect(r.error?.details?.reason).toBe('wrong_status');

    r = await t(editor, 'submit');
    expect(r.status).toBe(200);
    rev = r.result!.rev as number;

    // An editor can't approve; a stale revision is refused.
    expect((await t(editor, 'approve')).status).toBe(403);
    expect((await t(reviewer, 'approve', rev - 1)).error?.details?.reason).toBe('stale');

    r = await t(reviewer, 'approve');
    expect(r.result).toMatchObject({ review_status: 'approved', active: false });
    rev = r.result!.rev as number;

    // Reviewers can't publish; editors can.
    expect((await t(reviewer, 'publish')).status).toBe(403);
    r = await t(editor, 'publish');
    expect(r.result).toMatchObject({ review_status: 'approved', active: true });
    rev = r.result!.rev as number;
    expect(await offer()).toMatchObject({ review_status: 'approved', active: true });

    // An edit takes it offline and back to draft.
    r = await call('adminUpdatePortalOffer', editor, {
      id,
      expected_rev: rev,
      fields: { ...fields, price_display: '$59' },
    });
    expect(r.result).toMatchObject({ changed: true });
    rev = r.result!.rev as number;
    expect(await offer()).toMatchObject({ review_status: 'draft', active: false, version: 2, price_display: '$59' });

    // The list shows it to any staff role, with the workflow.
    const safety = await staff('safety_reviewer');
    const list = await call('adminListPortalOffers', safety);
    const mine = (list.result!.offers as Array<Record<string, unknown>>).find((o) => o.id === id);
    expect(mine).toMatchObject({ review_status: 'draft', rev, version_editors: [editor.uid] });

    r = await t(editor, 'archive');
    expect(r.result).toMatchObject({ review_status: 'archived', active: false });

    const entries = await auditFor(id);
    expect(entries.map((e) => e.action)).toEqual([
      'admin.portal_offer_created',
      'admin.portal_offer_submitted',
      'admin.portal_offer_approved',
      'admin.portal_offer_published',
      'admin.portal_offer_updated',
      'admin.portal_offer_archived',
    ]);
    expect(entries[2]).toMatchObject({ actor: `admin:${reviewer.uid}`, details: { from: 'in_review', to: 'approved', mfa: 'waiver' } });
    expect(entries[4].details).toMatchObject({ from: 'approved', to: 'draft', was_active: true, fields: 'price_display' });
    // Ids, statuses and field names only: no offer text in the log.
    expect(JSON.stringify(entries)).not.toMatch(/Gut health|Dr\. Gokula|\$49|\$59/);
  });

  it('two-person rule: an admin who edited the offer cannot approve it', async () => {
    const admin = await staff('admin');
    const created = await call('adminCreatePortalOffer', admin, { fields });
    const id = created.result!.id as string;
    let r = await call('adminTransitionPortalOffer', admin, { id, expected_rev: 1, action: 'submit' });
    r = await call('adminTransitionPortalOffer', admin, { id, expected_rev: r.result!.rev, action: 'approve' });
    expect(r.status).toBe(400);
    expect(r.error?.details?.reason).toBe('own_offer');
    expect((await db().doc(`portal_offers/${id}`).get()).get('review_status')).toBe('in_review');
  });

  it('a safety reviewer can take a live offer down', async () => {
    const editor = await staff('content_editor');
    const reviewer = await staff('clinical_reviewer');
    const safety = await staff('safety_reviewer');
    const id = (await call('adminCreatePortalOffer', editor, { fields })).result!.id as string;
    let rev = 1;
    for (const [who, action] of [
      [editor, 'submit'],
      [reviewer, 'approve'],
      [editor, 'publish'],
    ] as const) {
      const r = await call('adminTransitionPortalOffer', who, { id, expected_rev: rev, action });
      rev = r.result!.rev as number;
    }
    const r = await call('adminTransitionPortalOffer', safety, { id, expected_rev: rev, action: 'unpublish' });
    expect(r.result).toMatchObject({ active: false, review_status: 'approved' });
  });

  it('an unchanged save writes nothing and logs nothing', async () => {
    const editor = await staff('content_editor');
    const id = (await call('adminCreatePortalOffer', editor, { fields })).result!.id as string;
    const r = await call('adminUpdatePortalOffer', editor, { id, expected_rev: 1, fields });
    expect(r.result).toMatchObject({ changed: false, rev: 1 });
    expect((await auditFor(id)).length).toBe(1);
  });
});
