import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
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
  it('the Why is short text: up to 280 characters (FR-ONB-05)', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice');
    const now = meta().updated_at;
    await assertSucceeds(
      updateDoc(ref, { why_statement: 'x'.repeat(280), onboarding_step: 'assessment', updated_at: now }),
    );
    await assertFails(updateDoc(ref, { why_statement: 'x'.repeat(281), updated_at: now }));
    await assertFails(updateDoc(ref, { why_statement: 42, updated_at: now }));
    await assertFails(updateDoc(doc(as(BOB), 'users/alice'), { why_statement: 'hi', updated_at: now }));
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

  // T-AVT-08b: the 3D coach.
  const coach = (o: Record<string, unknown> = {}) => ({
    type: '3d_adult',
    source: 'default',
    coach_id: 'green_hijab',
    coach_name: 'Asha',
    background: 2,
    raw_media_retained: false,
    ...meta(),
    ...o,
  });

  it('picks a ready-made coach, renames it, changes the background', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/avatar/current');
    await assertSucceeds(setDoc(ref, coach()));
    await assertSucceeds(updateDoc(ref, { coach_id: 'wheelchair', coach_name: 'Sam', background: 5 }));
    await assertSucceeds(updateDoc(ref, { coach_name: deleteField() }));
  });

  it('an older cartoon doc can become a 3D coach', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/avatar/current': avatar() });
    await assertSucceeds(
      updateDoc(doc(as(ALICE), 'users/alice/avatar/current'), {
        type: '3d_adult', source: 'default', coach_id: 'brown_hair', background: 0,
      }),
    );
  });

  it('only known coaches, names of 1 to 20 characters, 6 backgrounds', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/avatar/current');
    await assertFails(setDoc(ref, coach({ coach_id: 'someone_else' })));
    await assertFails(setDoc(ref, coach({ coach_name: '' })));
    await assertFails(setDoc(ref, coach({ coach_name: 'x'.repeat(21) })));
    await assertFails(setDoc(ref, coach({ background: 6 })));
    await assertFails(setDoc(ref, coach({ raw_media_retained: true })));
  });

  it('made-for-you avatars and frame sets are server-only', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/avatar/current');
    await assertFails(setDoc(ref, coach({ source: 'selfie' })));
    await assertFails(setDoc(ref, coach({ frames_version: 3 })));
    await seed(env, { 'users/alice/avatar/current': coach() });
    await assertFails(updateDoc(ref, { source: 'built' }));
    await assertFails(updateDoc(ref, { frames_version: 2 }));
    // A server-made selfie coach: renaming is fine, and so is going back
    // to a ready-made coach.
    await seed(env, {
      'users/alice/avatar/current': coach({ source: 'selfie', frames_version: 1 }),
    });
    await assertSucceeds(updateDoc(ref, { coach_name: 'Mira' }));
    await assertFails(updateDoc(ref, { frames_version: 9 }));
    await assertSucceeds(updateDoc(ref, { source: 'default', coach_id: 'short_curls' }));
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
  it('cannot change status of a cloned voice, vendor id, create clones or delete', async () => {
    await seed(env, {
      'users/alice/voices/c1': { kind: 'self_clone', vendor_voice_id: 'v-c1', status: 'active', speed: 1, style: 'calm', ...meta() },
    });
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/c1'), { status: 'revoked' }));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/v1'), { vendor_voice_id: 'clone' }));
    await assertFails(
      setDoc(doc(as(ALICE), 'users/alice/voices/v2'), { kind: 'self_clone', status: 'active', ...meta() }),
    );
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice/voices/v1')));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/voices/v1')));
  });
});

describe('focus choices (T-ONB-03d)', () => {
  const ref = () => doc(as(ALICE), 'users/alice');
  const upd = (o: Record<string, unknown>) =>
    updateDoc(ref(), { ...o, updated_at: meta().updated_at });

  it('owner saves 1 or 2 known focus choices, the driver and the activity answer', async () => {
    await seedAdult(env);
    await assertSucceeds(upd({ focus_choices: ['move_more'], focus_driver: 'movement', activity_limited: false }));
    await assertSucceeds(upd({ focus_choices: ['sleep_better', 'less_stress'], activity_limited: true }));
  });
  it('rejects none, more than 2, unknown choices and a non-bool activity answer', async () => {
    await seedAdult(env);
    await assertFails(upd({ focus_choices: [] }));
    await assertFails(upd({ focus_choices: ['move_more', 'sleep_better', 'eat_better'] }));
    await assertFails(upd({ focus_choices: ['lose_10kg'] }));
    await assertFails(upd({ activity_limited: 'yes' }));
    await assertFails(upd({ focus_driver: 'x'.repeat(41) }));
  });
});

describe('starter plan (T-ONB-03e: the app writes 7 days)', () => {
  const day = (o: Record<string, unknown> = {}) => ({
    next_step: { title: 'Walk for 10 minutes after lunch', reason: 'r', anchor: 'After lunch', minutes: 10,
      smaller_title: 'Walk for 5 minutes after lunch', smaller_minutes: 5, focus: 'move_more' },
    alternatives: [], supporting: [{ id: 'water_breakfast', title: 'Water', anchor: 'With breakfast' }],
    mode: 'normal', day_number: 1, source: 'starter_v1', template_version: 1, ...meta(), ...o,
  });
  const ref = (d = '2026-10-15', who = ALICE) => doc(as(who), `users/alice/daily_plans/${d}`);

  it('owner writes starter days and may rewrite them (time edits)', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), day()));
    await assertSucceeds(setDoc(ref(), day({ mode: 'gentle', updated_at: meta().updated_at })));
    await assertSucceeds(getDoc(ref()));
    await assertFails(deleteDoc(ref()));
    await assertFails(setDoc(ref('2026-10-16', BOB), day()));
  });
  it('fixed shape: sizes, at most 2 supporting habits, days 1-7', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), day({ source: 'nightly' })));
    await assertFails(setDoc(ref(), day({ next_step: { title: 'x', minutes: 45 } })));
    await assertFails(setDoc(ref(), day({ supporting: [1, 2, 3] })));
    await assertFails(setDoc(ref(), day({ day_number: 8 })));
    await assertFails(setDoc(ref(), day({ briefing_media_url: 'x' })));
    await assertFails(setDoc(ref('today'), day()));
  });
  it('never overwrites a plan the server wrote', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/daily_plans/2026-10-15': { next_step: {}, source: 'nightly', ...meta() } });
    await assertFails(setDoc(ref(), day()));
  });
  it('touchpoint times on the profile are HH:MM', async () => {
    await seedAdult(env);
    const p = doc(as(ALICE), 'users/alice');
    const tp = (o: Record<string, unknown> = {}) => ({ morning: '07:00', midday: '13:00', evening: '20:30', ...o });
    await assertSucceeds(updateDoc(p, { touchpoints: tp(), updated_at: meta().updated_at }));
    await assertFails(updateDoc(p, { touchpoints: tp({ evening: '25:00' }), updated_at: meta().updated_at }));
    await assertFails(updateDoc(p, { touchpoints: tp({ night: '23:00' }), updated_at: meta().updated_at }));
  });
});

describe('profile settings (T-ONB-03f)', () => {
  const upd = (o: Record<string, unknown>) =>
    updateDoc(doc(as(ALICE), 'users/alice'), { ...o, updated_at: meta().updated_at });

  it('coach name, appearance, quiet hours and reminder categories', async () => {
    await seedAdult(env);
    await assertSucceeds(upd({ coach_name: 'Maya' }));
    await assertSucceeds(upd({ appearance: { theme: 'dark', text_scale: 1.15 } }));
    await assertSucceeds(upd({ quiet_hours: { start: '21:30', end: '06:30' } }));
    await assertSucceeds(upd({ notification_categories: { greeting: true, nudge: false, reflection: true } }));
  });
  it('rejects bad values', async () => {
    await seedAdult(env);
    await assertFails(upd({ coach_name: '' }));
    await assertFails(upd({ coach_name: 'x'.repeat(21) }));
    await assertFails(upd({ appearance: { theme: 'neon', text_scale: 1 } }));
    await assertFails(upd({ appearance: { theme: 'dark', text_scale: 3 } }));
    await assertFails(upd({ quiet_hours: { start: '9pm', end: '06:30' } }));
    await assertFails(upd({ notification_categories: { greeting: 'yes', nudge: true, reflection: true } }));
    await assertFails(upd({ notification_categories: { marketing: true } }));
  });
});

describe('routine mode (T-GOL-03b: travel, sick day, busy week)', () => {
  const upd = (o: Record<string, unknown>) =>
    updateDoc(doc(as(ALICE), 'users/alice'), { ...o, updated_at: meta().updated_at });

  it('turns a mode on until a date, and off again', async () => {
    await seedAdult(env);
    await assertSucceeds(upd({ routine_mode: { kind: 'travel', until: '2026-10-30' } }));
    await assertSucceeds(upd({ routine_mode: { kind: 'sick', until: '2026-10-24' } }));
    await assertSucceeds(upd({ routine_mode: { kind: 'busy', until: '2026-10-30' } }));
    await assertSucceeds(upd({ routine_mode: { kind: 'none' } }));
  });
  it('rejects other kinds, bad dates and extra fields', async () => {
    await seedAdult(env);
    await assertFails(upd({ routine_mode: { kind: 'holiday', until: '2026-10-30' } }));
    await assertFails(upd({ routine_mode: { kind: 'travel' } }));
    await assertFails(upd({ routine_mode: { kind: 'travel', until: 'next week' } }));
    await assertFails(upd({ routine_mode: { kind: 'none', until: '2026-10-30' } }));
    await assertFails(upd({ routine_mode: { kind: 'sick', until: '2026-10-24', streak_pause: true } }));
    await assertFails(upd({ routine_mode: 'sick' }));
  });
});

describe('routine reminders per day (T-GOL-03d)', () => {
  const upd = (o: Record<string, unknown>) =>
    updateDoc(doc(as(ALICE), 'users/alice'), { ...o, updated_at: meta().updated_at });

  it('0 (off) to 10', async () => {
    await seedAdult(env);
    await assertSucceeds(upd({ routine_reminders_per_day: 0 }));
    await assertSucceeds(upd({ routine_reminders_per_day: 6 }));
    await assertSucceeds(upd({ routine_reminders_per_day: 10 }));
    await assertFails(upd({ routine_reminders_per_day: 11 }));
    await assertFails(upd({ routine_reminders_per_day: -1 }));
    await assertFails(upd({ routine_reminders_per_day: 2.5 }));
    await assertFails(upd({ routine_reminders_per_day: '6' }));
  });
});

describe('library voices (T-ONB-03c: chosen in the app)', () => {
  const lib = (o: Record<string, unknown> = {}) => ({
    kind: 'library', vendor_voice_id: 'kokoro:af_heart', status: 'active', speed: 1, style: 'calm', ...meta(), ...o,
  });
  const ref = (id = 'lw-warm', who = ALICE) => doc(as(who), `users/alice/voices/${id}`);

  it('adult owner picks a library voice, then switches the active one', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), lib()));
    await assertSucceeds(setDoc(ref('lw-clear'), lib({ vendor_voice_id: 'kokoro:bm_george' })));
    await assertSucceeds(updateDoc(ref(), { status: 'inactive', updated_at: meta().updated_at }));
    await assertSucceeds(updateDoc(ref('lw-clear'), { speed: 1.2, style: 'energetic' }));
    await assertFails(setDoc(ref('lw-gentle', BOB), lib()));
  });
  it('only fixed fields, catalogue ids, and speed 0.8-1.2', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref('my-voice'), lib()));
    await assertFails(setDoc(ref(), lib({ kind: 'self_clone' })));
    await assertFails(setDoc(ref(), lib({ consent_id: 'c1' })));
    await assertFails(setDoc(ref(), lib({ speed: 1.5 })));
    await assertFails(setDoc(ref(), lib({ style: 'whisper' })));
    await assertFails(setDoc(ref(), lib({ status: 'revoked' })));
    await assertSucceeds(setDoc(ref(), lib({ speed: 0.8 })));
    await assertFails(updateDoc(ref(), { vendor_voice_id: 'elevenlabs:x' }));
    await assertFails(updateDoc(ref(), { status: 'revoked' }));
  });
  it('nothing before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), lib()));
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

describe('checkins (T-DLY-02: mood first, one per local date)', () => {
  const checkin = (o: Record<string, unknown> = {}) => ({
    mood: 4, energy: 3, sleep: 4, stress: 2, time_available: 10,
    barrier_text: 'Long meeting day', source: 'app', gentle_day: false,
    ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/checkins/2026-10-13');

  it('owner checks in; a same-day re-submit updates it (idempotent by date)', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), checkin()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), checkin({ mood: 5, created_at: saved.created_at, updated_at: meta().updated_at })),
    );
    await assertSucceeds(getDoc(ref()));
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/checkins/2026-10-13')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/checkins/2026-10-14'), checkin()));
  });
  it('mood alone is enough; the other answers are optional', async () => {
    await seedAdult(env);
    await assertSucceeds(
      setDoc(ref(), { mood: 3, source: 'app', gentle_day: false, ...meta() }),
    );
  });
  it('mood is required and every answer must be in range', async () => {
    await seedAdult(env);
    const { mood: _, ...noMood } = checkin();
    await assertFails(setDoc(ref(), noMood));
    await assertFails(setDoc(ref(), checkin({ mood: 0 })));
    await assertFails(setDoc(ref(), checkin({ energy: 6 })));
    await assertFails(setDoc(ref(), checkin({ sleep: 2.5 })));
    await assertFails(setDoc(ref(), checkin({ time_available: 15 })));
    await assertFails(setDoc(ref(), checkin({ source: 'web' })));
    await assertFails(setDoc(ref(), checkin({ barrier_text: 'x'.repeat(141) })));
    await assertSucceeds(setDoc(ref(), checkin({ barrier_text: 'x'.repeat(140) })));
  });
  it('rejects bad date ids and unknown fields', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/checkins/today'), checkin()));
    await assertFails(setDoc(ref(), checkin({ notes_for_coach: 'hi' })));
  });
  it('safety floor: low mood or high stress must be a gentle day (spec 15.3)', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), checkin({ mood: 2, gentle_day: false })));
    await assertFails(setDoc(ref(), checkin({ mood: 4, stress: 4, gentle_day: false })));
    const day = (d: string) => doc(as(ALICE), `users/alice/checkins/2026-10-${d}`);
    await assertSucceeds(setDoc(day('13'), checkin({ mood: 2, gentle_day: true })));
    await assertSucceeds(setDoc(day('14'), checkin({ mood: 5, stress: 5, gentle_day: true })));
    // A gentle day may also be set for other reasons (a red flag in the text).
    await assertSucceeds(setDoc(day('15'), checkin({ mood: 5, stress: 1, gentle_day: true })));
  });
  it('gentle_day must be present as true or false', async () => {
    await seedAdult(env);
    const { gentle_day: _, ...noFlag } = checkin();
    await assertFails(setDoc(ref(), noFlag));
  });
  it('created_at never changes on update', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/checkins/2026-10-13': checkin() });
    await assertFails(
      setDoc(ref(), checkin({ created_at: meta().created_at, updated_at: meta().updated_at, mood: 5 })),
    );
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), checkin()));
  });
});

describe('reflections (FR-DLY-05, T-UI-01d: one per local date)', () => {
  const reflection = (o: Record<string, unknown> = {}) => ({
    text: 'Walked after lunch', prompt: 'went_well', source: 'app', ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/reflections/2026-10-14');

  it('owner saves and edits the same day; nobody else can read or write', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), reflection()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), reflection({ text: 'Walked and slept well', created_at: saved.created_at, updated_at: meta().updated_at })),
    );
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/reflections/2026-10-14')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/reflections/2026-10-15'), reflection()));
  });
  it('text is 1 to 500 characters; prompt and source are fixed values', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), reflection({ text: '' })));
    await assertFails(setDoc(ref(), reflection({ text: 'x'.repeat(501) })));
    await assertFails(setDoc(ref(), reflection({ text: 42 })));
    await assertFails(setDoc(ref(), reflection({ prompt: 'anything' })));
    await assertFails(setDoc(ref(), reflection({ source: 'web' })));
    await assertSucceeds(setDoc(ref(), reflection({ text: 'x'.repeat(500) })));
  });
  it('rejects bad date ids, unknown fields and missing meta', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/reflections/today'), reflection()));
    await assertFails(setDoc(ref(), reflection({ mood: 3 })));
    const { schema_version: _, ...noMeta } = reflection();
    await assertFails(setDoc(ref(), noMeta));
  });
  it('created_at never changes on update', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/reflections/2026-10-14': reflection() });
    await assertFails(
      setDoc(ref(), reflection({ created_at: meta().created_at, updated_at: meta().updated_at })),
    );
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), reflection()));
  });
});

describe('routines (T-GOL-03a: My Daily Routine)', () => {
  const routine = (o: Record<string, unknown> = {}) => ({
    name: 'Weekdays', days: ['mon', 'tue', 'wed', 'thu', 'fri'], active: true, ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/routines/r1');

  it('owner creates, renames and pauses; nobody else; never deleted', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), routine()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), routine({ name: 'Workdays', active: false, created_at: saved.created_at, updated_at: meta().updated_at })),
    );
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/routines/r1')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/routines/r2'), routine()));
  });
  it('rejects bad names, days, ids, unknown fields and missing meta', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), routine({ name: '' })));
    await assertFails(setDoc(ref(), routine({ name: 'x'.repeat(41) })));
    await assertFails(setDoc(ref(), routine({ days: [] })));
    await assertFails(setDoc(ref(), routine({ days: ['mon', 'mon'] })));
    await assertFails(setDoc(ref(), routine({ days: ['funday'] })));
    await assertFails(setDoc(ref(), routine({ active: 'yes' })));
    await assertFails(setDoc(ref(), routine({ items: [] })));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/routines/bad_id'), routine()));
    const { schema_version: _, ...noMeta } = routine();
    await assertFails(setDoc(ref(), noMeta));
    await assertSucceeds(setDoc(ref(), routine({ days: ['sat', 'sun'] })));
  });
  it('created_at never changes on update', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/routines/r1': routine() });
    await assertFails(setDoc(ref(), routine({ created_at: meta().created_at, updated_at: meta().updated_at })));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), routine()));
  });
});

describe('routine_items (T-GOL-03a: one document per item, D-44)', () => {
  const water = (o: Record<string, unknown> = {}) => ({
    routine_id: 'r1', catalog_id: 'drink_water', label: 'Drink water', icon: 'water',
    time: '07:15', duration_min: 2, reminder: true, avatar_announce: true, order: 0, ...meta(), ...o,
  });
  const custom = (o: Record<string, unknown> = {}): Record<string, unknown> => {
    const { catalog_id: _, ...rest } = water({ label: 'Call mom', icon: 'heart', custom: true, ...o });
    return rest;
  };
  const ref = (id = 'i1') => doc(as(ALICE), `users/alice/routine_items/${id}`);

  it('owner adds, edits and deletes items; nobody else can', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), water()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), water({ time: '07:30', reminder: false, created_at: saved.created_at, updated_at: meta().updated_at })),
    );
    await assertFails(getDoc(doc(as(BOB), 'users/alice/routine_items/i1')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/routine_items/i2'), water()));
    await assertFails(deleteDoc(doc(as(BOB), 'users/alice/routine_items/i1')));
    await assertSucceeds(deleteDoc(ref()));
  });
  it('custom items: label 1 to 40 characters, never also a catalog item', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref('c1'), custom()));
    await assertFails(setDoc(ref('c2'), custom({ label: '' })));
    await assertFails(setDoc(ref('c2'), custom({ label: 'x'.repeat(41) })));
    await assertFails(setDoc(ref('c2'), custom({ custom: false })));
    await assertFails(setDoc(ref('c2'), water({ custom: true })));
    const { catalog_id: _, ...neither } = water();
    await assertFails(setDoc(ref('c2'), neither));
  });
  it('an item never switches between catalog and custom', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/routine_items/c1': custom(), 'users/alice/routine_items/i1': water() });
    const c = (await getDoc(ref('c1'))).data()!;
    const i = (await getDoc(ref('i1'))).data()!;
    const { custom: _c, ...toCatalog } = custom({ catalog_id: 'drink_water', created_at: c.created_at, updated_at: meta().updated_at });
    await assertFails(setDoc(ref('c1'), toCatalog));
    await assertFails(setDoc(ref('i1'), custom({ created_at: i.created_at, updated_at: meta().updated_at })));
    await assertFails(
      setDoc(ref('i1'), water({ catalog_id: 'bedtime', created_at: i.created_at, updated_at: meta().updated_at })),
    );
  });
  it('catalog items only from the approved list (no fasting, calories, weight or medication)', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), water({ catalog_id: 'fasting' })));
    await assertFails(setDoc(ref(), water({ catalog_id: 'take_medication' })));
    await assertFails(setDoc(ref(), water({ icon: 'pill' })));
    await assertSucceeds(setDoc(ref(), water({ catalog_id: 'bedtime', label: 'Bedtime', icon: 'bed' })));
  });
  it('checks time, duration, days, ids and fields', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), water({ time: '7:15' })));
    await assertFails(setDoc(ref(), water({ time: '24:00' })));
    await assertFails(setDoc(ref(), water({ duration_min: 0 })));
    await assertFails(setDoc(ref(), water({ duration_min: 181 })));
    await assertFails(setDoc(ref(), water({ duration_min: 2.5 })));
    await assertFails(setDoc(ref(), water({ reminder: 'yes' })));
    await assertFails(setDoc(ref(), water({ avatar_announce: 1 })));
    await assertFails(setDoc(ref(), water({ order: 'first' })));
    await assertFails(setDoc(ref(), water({ note: 'extra' })));
    await assertFails(setDoc(ref(), water({ routine_id: 'bad_id' })));
    await assertFails(setDoc(ref('bad_id'), water()));
    await assertFails(setDoc(ref(), water({ days: [] })));
    await assertFails(setDoc(ref(), water({ days: ['monday'] })));
    await assertSucceeds(setDoc(ref(), water({ days: ['sat', 'sun'], duration_min: 180 })));
    const { schema_version: _, ...noMeta } = water();
    await assertFails(setDoc(ref('i2'), noMeta));
  });
  it('created_at never changes on update', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/routine_items/i1': water() });
    await assertFails(setDoc(ref(), water({ created_at: meta().created_at, updated_at: meta().updated_at })));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), water()));
  });
});

describe('routine_logs (T-GOL-03a: idempotent date_itemId)', () => {
  const log = (o: Record<string, unknown> = {}) => ({
    date: '2026-10-24', item_id: 'i1', status: 'done', source: 'app', ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/routine_logs/2026-10-24_i1');

  it('owner logs and changes the status; nobody else; never deleted', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), log()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), log({ status: 'skipped', source: 'widget', created_at: saved.created_at, updated_at: meta().updated_at })),
    );
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/routine_logs/2026-10-24_i1')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/routine_logs/2026-10-24_i1'), log()));
  });
  it('id must be date_itemId; date and item never change', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/routine_logs/random'), log()));
    await assertFails(setDoc(ref(), log({ date: '2026-10-25' })));
    await assertFails(setDoc(ref(), log({ item_id: 'i2' })));
    await seed(env, { 'users/alice/routine_logs/2026-10-24_i1': log() });
    await assertFails(updateDoc(ref(), { date: '2026-10-25', updated_at: meta().updated_at }));
  });
  it('status, source and fields are fixed values; meta required', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), log({ status: 'missed' })));
    await assertFails(setDoc(ref(), log({ source: 'watch' })));
    await assertFails(setDoc(ref(), log({ note: 'tired' })));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/routine_logs/today_i1'), log({ date: 'today' })));
    const { schema_version: _, ...noMeta } = log();
    await assertFails(setDoc(ref(), noMeta));
    await seed(env, { 'users/alice/routine_logs/2026-10-24_i1': log() });
    await assertFails(setDoc(ref(), log({ created_at: meta().created_at, updated_at: meta().updated_at })));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), log()));
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
