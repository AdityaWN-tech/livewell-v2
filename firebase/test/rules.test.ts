import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

import {
  ALICE,
  BOB,
  makeEnv,
  meta,
  profile,
  seed,
  seedAdult,
  serverMeta,
} from './helpers';

let env: RulesTestEnvironment;
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await makeEnv();
});
afterAll(async () => {
  await env.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
});

describe('users/{uid} profile', () => {
  it('owner creates a profile after the 18+ gate', async () => {
    await assertSucceeds(setDoc(doc(as(ALICE), 'users/alice'), profile()));
  });
  it('no profile is stored without age confirmation (FR-ONB-04)', async () => {
    await assertFails(
      setDoc(doc(as(ALICE), 'users/alice'), profile({ age_confirmed: false })),
    );
  });
  it('cannot create without created_at/updated_at/schema_version', async () => {
    const { schema_version: _, ...noVersion } = profile();
    await assertFails(setDoc(doc(as(ALICE), 'users/alice'), noVersion));
  });
  it('cannot set server-only fields (ed_safe_mode, plan_tier)', async () => {
    await assertFails(
      setDoc(doc(as(ALICE), 'users/alice'), profile({ ed_safe_mode: false })),
    );
    await seedAdult(env);
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice'), { plan_tier: 'premium' }));
  });
  it('owner updates allowed fields', async () => {
    await seedAdult(env);
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users/alice'), {
        why_statement: 'Energy to travel with my family',
        updated_at: meta().updated_at,
      }),
    );
  });
  it('cannot switch age_confirmed off', async () => {
    await seedAdult(env);
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice'), { age_confirmed: false }));
  });
  it('server-only field already set by the server cannot be changed', async () => {
    await seed(env, { 'users/alice': profile({ ed_safe_mode: true }) });
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice'), { ed_safe_mode: false }));
  });
  it('others and signed-out users cannot read or write it', async () => {
    await seedAdult(env);
    await assertFails(getDoc(doc(as(BOB), 'users/alice')));
    await assertFails(getDoc(doc(anon(), 'users/alice')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice'), profile()));
  });
  it('owner reads it, but cannot delete it (server deletion, FR-SET-02)', async () => {
    await seedAdult(env);
    await assertSucceeds(getDoc(doc(as(ALICE), 'users/alice')));
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice')));
  });
});

describe('consents (append-only, FR-ONB-02/03)', () => {
  const consent = (o: Record<string, unknown> = {}) => ({
    type: 'terms',
    doc_version: 'terms-1.0',
    granted: true,
    app_version: '1.0.0',
    ...serverMeta(),
    ...o,
  });

  it('adult owner appends a consent record', async () => {
    await seedAdult(env);
    await assertSucceeds(addDoc(collection(as(ALICE), 'users/alice/consents'), consent()));
  });
  it('a revocation is a new record, not an edit', async () => {
    await seedAdult(env);
    await seed(env, {
      'users/alice/consents/c1': { type: 'marketing', doc_version: 'm-1', granted: true, app_version: '1.0.0', ...meta() },
    });
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/consents/c1'), { granted: false }));
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice/consents/c1')));
    await assertSucceeds(
      addDoc(collection(as(ALICE), 'users/alice/consents'), consent({ type: 'marketing', granted: false })),
    );
  });
  it('timestamp must come from the server clock', async () => {
    await seedAdult(env);
    await assertFails(
      addDoc(collection(as(ALICE), 'users/alice/consents'), { ...consent(), ...meta() }),
    );
  });
  it('rejects missing version or unknown fields', async () => {
    await seedAdult(env);
    const { doc_version: _, ...noVersion } = consent();
    await assertFails(addDoc(collection(as(ALICE), 'users/alice/consents'), noVersion));
    await assertFails(
      addDoc(collection(as(ALICE), 'users/alice/consents'), consent({ verified_by_server: true })),
    );
  });
  it('nothing stored before the 18+ gate, and not for others', async () => {
    await assertFails(addDoc(collection(as(ALICE), 'users/alice/consents'), consent()));
    await seed(env, { 'users/alice': profile({ age_confirmed: false }) });
    await assertFails(addDoc(collection(as(ALICE), 'users/alice/consents'), consent()));
    await seedAdult(env);
    await assertFails(addDoc(collection(as(BOB), 'users/alice/consents'), consent()));
  });
  it('owner reads own consents only', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/consents/c1': { type: 'terms', ...meta() } });
    await assertSucceeds(getDoc(doc(as(ALICE), 'users/alice/consents/c1')));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/consents/c1')));
  });
});

describe('avatar', () => {
  const avatar = (o: Record<string, unknown> = {}) => ({
    type: 'stylized',
    style_config: { preset: 'p1' },
    raw_media_retained: false,
    ...meta(),
    ...o,
  });

  it('adult owner creates and restyles avatar/current', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(doc(as(ALICE), 'users/alice/avatar/current'), avatar()));
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users/alice/avatar/current'), { style_config: { preset: 'p2' } }),
    );
    await assertSucceeds(getDoc(doc(as(ALICE), 'users/alice/avatar/current')));
  });
  it('vendor fields are server-only', async () => {
    await seedAdult(env);
    await assertFails(
      setDoc(doc(as(ALICE), 'users/alice/avatar/current'), avatar({ vendor_avatar_id: 'x' })),
    );
    await seed(env, { 'users/alice/avatar/current': avatar({ vendor_avatar_id: 'v1' }) });
    await assertFails(
      updateDoc(doc(as(ALICE), 'users/alice/avatar/current'), { vendor_avatar_id: 'other' }),
    );
  });
  it('only "current", valid type, no client delete', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/avatar/second'), avatar()));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/avatar/current'), avatar({ type: 'cartoon' })));
    await seed(env, { 'users/alice/avatar/current': avatar() });
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/avatar/current'), { type: 'cartoon' }));
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice/avatar/current')));
  });
});

describe('voices (status and vendor ids server-only)', () => {
  beforeEach(async () => {
    await seedAdult(env);
    await seed(env, {
      'users/alice/voices/v1': {
        kind: 'library', vendor_voice_id: 'lib-1', status: 'active', speed: 1, style: 'calm', ...meta(),
      },
    });
  });
  it('owner reads and changes speed/style within 0.8-1.2x (FR-VOC-01)', async () => {
    await assertSucceeds(getDoc(doc(as(ALICE), 'users/alice/voices/v1')));
    await assertSucceeds(updateDoc(doc(as(ALICE), 'users/alice/voices/v1'), { speed: 1.2, style: 'warm' }));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/v1'), { speed: 2 }));
  });
  it('cannot change status, vendor id, create or delete', async () => {
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/v1'), { status: 'revoked' }));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/v1'), { vendor_voice_id: 'clone' }));
    await assertFails(
      setDoc(doc(as(ALICE), 'users/alice/voices/v2'), { kind: 'self_clone', status: 'active', ...meta() }),
    );
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice/voices/v1')));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/voices/v1')));
  });
});

describe('assessments (saveable until completed)', () => {
  it('owner creates, saves progress, then cannot edit after completion', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/assessments/a1');
    await assertSucceeds(setDoc(ref, { bank_version: '1.0', answers: [], ...meta() }));
    await assertSucceeds(updateDoc(ref, { answers: [1, 2] }));
    await assertFails(updateDoc(ref, { bank_version: '2.0' }));
    await seed(env, {
      'users/alice/assessments/a1': { bank_version: '1.0', answers: [1], completed_at: meta().created_at, ...meta() },
    });
    await assertFails(updateDoc(ref, { answers: [3] }));
    await assertFails(deleteDoc(ref));
    await assertSucceeds(getDoc(ref));
  });
  it('needs a bank version, and the 18+ gate', async () => {
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/assessments/a1'), { bank_version: '1.0', ...meta() }));
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/assessments/a1'), { answers: [], ...meta() }));
  });
});

describe('goals and habits', () => {
  it('owner creates and edits; no deletes (pause instead)', async () => {
    await seedAdult(env);
    const goal = doc(as(ALICE), 'users/alice/goals/g1');
    await assertSucceeds(setDoc(goal, { action: 'walk', status: 'active', ...meta() }));
    await assertSucceeds(updateDoc(goal, { status: 'paused' }));
    await assertFails(deleteDoc(goal));
    await assertSucceeds(getDoc(goal));
    const habit = doc(as(ALICE), 'users/alice/habits/h1');
    await assertSucceeds(setDoc(habit, { title: '10-min walk after lunch', ...meta() }));
    await assertSucceeds(updateDoc(habit, { active: false }));
    await assertFails(deleteDoc(habit));
    await assertSucceeds(getDoc(habit));
  });
  it('habit needs a title; others cannot write', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habits/h1'), { ...meta() }));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/goals/g1'), { ...meta() }));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/goals/g1'), { action: 'walk' }));
  });
});

describe('habit_logs (idempotent date_habitId)', () => {
  const log = (o: Record<string, unknown> = {}) => ({
    date: '2026-10-13', habit_id: 'h1', status: 'done', source: 'widget', size_done: 10, ...meta(), ...o,
  });
  it('owner logs with the idempotent id and can change the status', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/habit_logs/2026-10-13_h1');
    await assertSucceeds(setDoc(ref, log()));
    await assertSucceeds(updateDoc(ref, { status: 'partial' }));
    await assertSucceeds(getDoc(ref));
    await assertFails(deleteDoc(ref));
  });
  it('rejects a mismatched id, bad status/source, or moving the date', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habit_logs/random'), log()));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habit_logs/2026-10-13_h1'), log({ status: 'perfect' })));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habit_logs/2026-10-13_h1'), log({ source: 'web' })));
    await seed(env, { 'users/alice/habit_logs/2026-10-13_h1': log() });
    await assertFails(
      updateDoc(doc(as(ALICE), 'users/alice/habit_logs/2026-10-13_h1'), { date: '2026-10-14' }),
    );
  });
});

describe('checkins (one per date, 1-5 scales)', () => {
  const checkin = (o: Record<string, unknown> = {}) => ({
    energy: 3, sleep: 4, stress: 2, mood: 4, time_available: 10, source: 'app', ...meta(), ...o,
  });
  it('owner checks in and can correct it the same day', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/checkins/2026-10-13');
    await assertSucceeds(setDoc(ref, checkin()));
    await assertSucceeds(updateDoc(ref, { mood: 5 }));
    await assertSucceeds(getDoc(ref));
    await assertFails(deleteDoc(ref));
  });
  it('rejects out-of-range values, odd time options and bad ids', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/checkins/2026-10-13');
    await assertFails(setDoc(ref, checkin({ energy: 6 })));
    await assertFails(setDoc(ref, checkin({ time_available: 15 })));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/checkins/today'), checkin()));
    await seed(env, { 'users/alice/checkins/2026-10-13': checkin() });
    await assertFails(updateDoc(ref, { stress: 0 }));
  });
});

describe('memory_facts (user approves or deletes, FR-CNV-05)', () => {
  beforeEach(async () => {
    await seedAdult(env);
    await seed(env, {
      'users/alice/memory_facts/f1': { fact: 'prefers morning walks', category: 'preference', status: 'proposed', ...meta() },
    });
  });
  it('owner saves, then deletes; a deleted fact stays deleted', async () => {
    const ref = doc(as(ALICE), 'users/alice/memory_facts/f1');
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(updateDoc(ref, { status: 'saved' }));
    await assertSucceeds(updateDoc(ref, { status: 'deleted' }));
    await assertFails(updateDoc(ref, { status: 'saved' }));
  });
  it('cannot edit the fact text, create facts or hard-delete', async () => {
    const ref = doc(as(ALICE), 'users/alice/memory_facts/f1');
    await assertFails(updateDoc(ref, { fact: 'something else' }));
    await assertFails(updateDoc(ref, { status: 'proposed' }));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/memory_facts/f2'), { fact: 'x', status: 'saved', ...meta() }));
    await assertFails(deleteDoc(ref));
  });
});

describe('portal_events (app events only, append-only)', () => {
  const ev = (event: string) => ({ event, offer_id: 'o1', click_id: 'c1', ...meta() });
  it('owner records shown/clicked/dismissed', async () => {
    await seedAdult(env);
    for (const e of ['card_shown', 'clicked', 'dismissed']) {
      await assertSucceeds(addDoc(collection(as(ALICE), 'users/alice/portal_events'), ev(e)));
    }
  });
  it('purchases and progress only come from webhooks; no edits', async () => {
    await seedAdult(env);
    for (const e of ['order', 'progress', 'completed']) {
      await assertFails(addDoc(collection(as(ALICE), 'users/alice/portal_events'), ev(e)));
    }
    await seed(env, { 'users/alice/portal_events/e1': ev('clicked') });
    await assertSucceeds(getDoc(doc(as(ALICE), 'users/alice/portal_events/e1')));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/portal_events/e1'), { event: 'order' }));
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice/portal_events/e1')));
    await assertFails(addDoc(collection(as(ALICE), 'users/alice/portal_events'), { event: 'clicked', ...meta() }));
  });
});

describe('server-written documents are read-only for the owner', () => {
  const paths = [
    'users/alice/daily_plans/2026-10-13',
    'users/alice/messages/m1',
    'users/alice/streaks/current',
    'users/alice/portal_link/current',
  ];
  for (const path of paths) {
    it(path, async () => {
      await seedAdult(env);
      await seed(env, { [path]: { x: 1, ...meta() } });
      await assertSucceeds(getDoc(doc(as(ALICE), path)));
      await assertFails(getDoc(doc(as(BOB), path)));
      await assertFails(setDoc(doc(as(ALICE), path), { x: 2, ...meta() }));
    });
  }
});

describe('global catalogues (approved and active only)', () => {
  it('portal_offers: active + approved readable when signed in', async () => {
    await seed(env, {
      'portal_offers/ok': { active: true, review_status: 'approved', ...meta() },
      'portal_offers/draft': { active: true, review_status: 'draft', ...meta() },
      'portal_offers/off': { active: false, review_status: 'approved', ...meta() },
    });
    await assertSucceeds(getDoc(doc(as(ALICE), 'portal_offers/ok')));
    await assertFails(getDoc(doc(as(ALICE), 'portal_offers/draft')));
    await assertFails(getDoc(doc(as(ALICE), 'portal_offers/off')));
    await assertFails(getDoc(doc(anon(), 'portal_offers/ok')));
    await assertFails(setDoc(doc(as(ALICE), 'portal_offers/new'), { active: true }));
  });
  it('content_items: approved readable, nothing writable', async () => {
    await seed(env, {
      'content_items/ok': { review_status: 'approved', ...meta() },
      'content_items/pending': { review_status: 'in_review', ...meta() },
    });
    await assertSucceeds(getDoc(doc(as(ALICE), 'content_items/ok')));
    await assertFails(getDoc(doc(as(ALICE), 'content_items/pending')));
    await assertFails(getDoc(doc(anon(), 'content_items/ok')));
    await assertFails(setDoc(doc(as(ALICE), 'content_items/x'), { review_status: 'approved' }));
  });
});

describe('server-only collections are closed to clients (11.1)', () => {
  for (const col of ['voice_consents', 'safety_events', 'audit_log']) {
    it(col, async () => {
      await seed(env, { [`${col}/x`]: { uid: ALICE, ...meta() } });
      await assertFails(getDoc(doc(as(ALICE), `${col}/x`)));
      await assertFails(setDoc(doc(as(ALICE), `${col}/y`), { uid: ALICE }));
    });
  }
  it('unknown collections are denied by default', async () => {
    await assertFails(setDoc(doc(as(ALICE), 'anything/x'), { a: 1 }));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/unknown/x'), { a: 1 }));
  });
});
