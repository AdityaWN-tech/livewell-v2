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
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
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

  it('only known coaches, names of 1 to 20 characters, 13 backgrounds (6 + 7 unlockable, D-87)', async () => {
    await seedAdult(env);
    const ref = doc(as(ALICE), 'users/alice/avatar/current');
    await assertFails(setDoc(ref, coach({ coach_id: 'someone_else' })));
    await assertFails(setDoc(ref, coach({ coach_name: '' })));
    await assertFails(setDoc(ref, coach({ coach_name: 'x'.repeat(21) })));
    await assertSucceeds(setDoc(ref, coach({ background: 12 })));
    await assertFails(setDoc(ref, coach({ background: 13 })));
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
  it('the voice gateway can trust kind and consent_id (T-VOC-07): the app sets neither', async () => {
    await seed(env, {
      'users/alice/voices/c1': { kind: 'loved_one', vendor_voice_id: 'v-c1', consent_id: 'vc_1', status: 'revoked', speed: 1, style: 'calm', ...meta() },
    });
    // A revoked clone can't be pointed at another consent or turned into a library voice.
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/c1'), { consent_id: 'vc_2' }));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/c1'), { kind: 'library', status: 'active' }));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/voices/v1'), { kind: 'self_clone' }));
    // Nor can a library voice be created carrying a consent id.
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/voices/lw-new'), {
      kind: 'library', vendor_voice_id: 'x', consent_id: 'vc_1', status: 'inactive', speed: 1, style: 'calm', ...meta(),
    }));
    // Consent records and coach messages are server-only.
    await assertFails(setDoc(doc(as(ALICE), 'voice_consents/vc_3'), { account_uid: 'alice', status: 'active' }));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/messages/m_new_0001'), { text: 'Say this', safety: { status: 'approved' } }));
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
    // The app sends the weekly review's switch too (T-DLY-03c).
    await assertSucceeds(upd({ notification_categories: { greeting: true, nudge: false, reflection: true, weekly: false } }));
  });
  it('moment playback and "Not today" (T-DLY-03e)', async () => {
    await seedAdult(env);
    await assertSucceeds(upd({ moment_playback: { auto_speak: false, captions: true } }));
    await assertSucceeds(upd({ not_today: { date: '2026-10-15', kinds: ['greeting'] } }));
    await assertSucceeds(upd({ not_today: { date: '2026-10-15', kinds: [] } }));
    await assertFails(upd({ moment_playback: { auto_speak: 'no', captions: true } }));
    await assertFails(upd({ moment_playback: { auto_speak: true } }));
    await assertFails(upd({ moment_playback: { auto_speak: true, captions: true, volume: 3 } }));
    await assertFails(upd({ not_today: { date: 'today', kinds: ['greeting'] } }));
    await assertFails(upd({ not_today: { date: '2026-10-15', kinds: ['marketing'] } }));
    await assertFails(upd({ not_today: { date: '2026-10-15', kinds: ['greeting'], note: 'x' } }));
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
    await assertFails(upd({ notification_categories: { greeting: true, nudge: true, reflection: true, weekly: 'yes' } }));
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

describe('goals and habits (Step 4a: one goal, two own habits)', () => {
  const goalData = (o: Record<string, unknown> = {}) => ({
    action: 'Walk after dinner', days_per_week: 5, minutes: 10, anchor: 'dinner',
    barrier_plan: 'Walk indoors if it rains', link_why: true, status: 'active',
    start_date: '2026-10-14', ...meta(), ...o,
  });
  const habitData = (o: Record<string, unknown> = {}) => ({
    title: 'Glass of water', anchor: 'wakeUp', minutes: 2, active: true, ...meta(), ...o,
  });
  it('owner creates and edits; pause and stop instead of delete', async () => {
    await seedAdult(env);
    const goal = doc(as(ALICE), 'users/alice/goals/primary');
    await assertSucceeds(setDoc(goal, goalData()));
    await assertSucceeds(updateDoc(goal, { status: 'paused' }));
    await assertSucceeds(updateDoc(goal, { status: 'active', start_date: '2026-10-20' }));
    await assertFails(deleteDoc(goal));
    await assertSucceeds(getDoc(goal));
    const habit = doc(as(ALICE), 'users/alice/habits/support_1');
    await assertSucceeds(setDoc(habit, habitData()));
    await assertSucceeds(updateDoc(habit, { active: false }));
    await assertFails(deleteDoc(habit));
    await assertSucceeds(getDoc(habit));
  });
  it('only one goal and two own habits (fixed ids, FR-GOL-01)', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/goals/g2'), goalData()));
    await assertSucceeds(setDoc(doc(as(ALICE), 'users/alice/habits/support_2'), habitData()));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habits/support_3'), habitData()));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habits/h1'), habitData()));
  });
  it('fixed shape: sizes, choices, no extra fields, created_at kept', async () => {
    await seedAdult(env);
    const goal = doc(as(ALICE), 'users/alice/goals/primary');
    await assertFails(setDoc(goal, goalData({ action: '' })));
    await assertFails(setDoc(goal, goalData({ action: 'x'.repeat(61) })));
    await assertFails(setDoc(goal, goalData({ days_per_week: 8 })));
    await assertFails(setDoc(goal, goalData({ minutes: 7 })));
    await assertFails(setDoc(goal, goalData({ anchor: 'noon' })));
    await assertFails(setDoc(goal, goalData({ status: 'done' })));
    await assertFails(setDoc(goal, goalData({ start_date: 'today' })));
    await assertFails(setDoc(goal, goalData({ weight_kg: 70 })));
    const habit = doc(as(ALICE), 'users/alice/habits/support_1');
    await assertFails(setDoc(habit, habitData({ title: '' })));
    await assertFails(setDoc(habit, habitData({ title: 'x'.repeat(41) })));
    await assertFails(setDoc(habit, habitData({ minutes: 30 })));
    await assertFails(setDoc(habit, habitData({ notes: 'free text' })));
    await seed(env, {
      'users/alice/goals/primary': goalData(),
      'users/alice/habits/support_1': habitData(),
    });
    const later = { created_at: new Date('2030-01-01') };
    await assertFails(updateDoc(goal, later));
    await assertFails(updateDoc(habit, later));
    await assertFails(updateDoc(habit, { minutes: 3 }));
  });
  it('others cannot read or write; the 18+ gate applies', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(BOB), 'users/alice/goals/primary'), goalData()));
    await seed(env, { 'users/alice/goals/primary': goalData() });
    await assertFails(getDoc(doc(as(BOB), 'users/alice/goals/primary')));
    await seed(env, { 'users/alice': profile({ age_confirmed: false }) });
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/habits/support_1'), habitData()));
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
  it('once gentle, a same-day redo keeps it gentle (spec 15.3, D-70)', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/checkins/2026-10-13': checkin({ mood: 1, gentle_day: true }) });
    const saved = (await getDoc(ref())).data()!;
    const redo = (o: Record<string, unknown>) =>
      setDoc(ref(), checkin({ created_at: saved.created_at, updated_at: meta().updated_at, ...o }));
    await assertFails(redo({ mood: 5, gentle_day: false }));
    await assertSucceeds(redo({ mood: 5, gentle_day: true }));
    // Not gentle yet: a later answer may still make it gentle.
    await seed(env, { 'users/alice/checkins/2026-10-14': checkin({ mood: 4, gentle_day: false }) });
    const ref14 = doc(as(ALICE), 'users/alice/checkins/2026-10-14');
    const saved14 = (await getDoc(ref14)).data()!;
    await assertSucceeds(
      setDoc(ref14, checkin({
        created_at: saved14.created_at, updated_at: meta().updated_at, stress: 5, gentle_day: true,
      })),
    );
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

describe('metrics (T-GOL-02: weight, blood pressure, glucose, meals; D-72)', () => {
  const at = () => Timestamp.now();
  const weight = (o: Record<string, unknown> = {}) => ({
    kind: 'weight', source: 'manual', measured_at: at(), value: 72.5, unit: 'kg', ...meta(), ...o,
  });
  const bp = (o: Record<string, unknown> = {}) => ({
    kind: 'blood_pressure', source: 'manual', measured_at: at(), systolic: 120, diastolic: 80, unit: 'mmHg', ...meta(), ...o,
  });
  const glucose = (o: Record<string, unknown> = {}) => ({
    kind: 'glucose', source: 'manual', measured_at: at(), value: 98, unit: 'mg/dL', ...meta(), ...o,
  });
  const meal = (o: Record<string, unknown> = {}) => ({
    kind: 'meal', source: 'manual', measured_at: at(), meal: 'lunch', ...meta(), ...o,
  });
  const ref = (id = 'm1') => doc(as(ALICE), `users/alice/metrics/${id}`);

  it('owner adds, reads and deletes; nobody else can read or write', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), weight()));
    await assertSucceeds(getDoc(ref()));
    await assertSucceeds(getDocs(collection(as(ALICE), 'users/alice/metrics')));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/metrics/m1')));
    await assertFails(getDocs(collection(as(BOB), 'users/alice/metrics')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/metrics/m2'), weight()));
    await assertFails(deleteDoc(doc(as(BOB), 'users/alice/metrics/m1')));
    await assertFails(getDoc(doc(anon(), 'users/alice/metrics/m1')));
    await assertSucceeds(deleteDoc(ref()));
  });
  it('points are never edited (delete and add again)', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/metrics/m1': weight() });
    await assertFails(setDoc(ref(), weight({ value: 73 })));
    await assertFails(updateDoc(ref(), { value: 73 }));
  });
  it('each kind with its own fields and units', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref('w-kg'), weight()));
    await assertSucceeds(setDoc(ref('w-lb'), weight({ value: 160.4, unit: 'lb' })));
    await assertSucceeds(setDoc(ref('bp'), bp()));
    await assertSucceeds(setDoc(ref('g'), glucose()));
    for (const m of ['breakfast', 'lunch', 'dinner', 'snack']) {
      await assertSucceeds(setDoc(ref(`meal-${m}`), meal({ meal: m })));
    }
    await assertSucceeds(setDoc(ref('health'), weight({ source: 'health' })));
    // Wrong unit for the kind.
    await assertFails(setDoc(ref(), weight({ unit: 'stone' })));
    await assertFails(setDoc(ref(), bp({ unit: 'kPa' })));
    await assertFails(setDoc(ref(), glucose({ unit: 'mmol/L' })));
    // Fields of another kind, or unknown ones.
    await assertFails(setDoc(ref(), weight({ systolic: 120 })));
    await assertFails(setDoc(ref(), meal({ value: 500 })));
    await assertFails(setDoc(ref(), meal({ note: 'pizza' })));
    await assertFails(setDoc(ref(), glucose({ meal: 'lunch' })));
    await assertFails(setDoc(ref(), meal({ meal: 'brunch' })));
    await assertFails(setDoc(ref(), weight({ kind: 'steps' })));
    await assertFails(setDoc(ref(), weight({ source: 'web' })));
  });
  it('limits catch typos only (D-72)', async () => {
    await seedAdult(env);
    // Edges are accepted, as they are: the app doesn't judge them.
    await assertSucceeds(setDoc(ref('a'), weight({ value: 20 })));
    await assertSucceeds(setDoc(ref('b'), weight({ value: 300 })));
    await assertSucceeds(setDoc(ref('c'), weight({ value: 660, unit: 'lb' })));
    await assertSucceeds(setDoc(ref('d'), bp({ systolic: 260, diastolic: 159 })));
    await assertSucceeds(setDoc(ref('e'), bp({ systolic: 51, diastolic: 30 })));
    await assertSucceeds(setDoc(ref('f'), glucose({ value: 20 })));
    await assertSucceeds(setDoc(ref('g'), glucose({ value: 600 })));
    await assertFails(setDoc(ref(), weight({ value: 19.9 })));
    await assertFails(setDoc(ref(), weight({ value: 301 })));
    await assertFails(setDoc(ref(), weight({ value: 43, unit: 'lb' })));
    await assertFails(setDoc(ref(), weight({ value: '72' })));
    await assertFails(setDoc(ref(), bp({ systolic: 261 })));
    await assertFails(setDoc(ref(), bp({ diastolic: 29 })));
    await assertFails(setDoc(ref(), bp({ systolic: 80, diastolic: 80 })));
    await assertFails(setDoc(ref(), bp({ systolic: 120.5 })));
    await assertFails(setDoc(ref(), glucose({ value: 601 })));
    await assertFails(setDoc(ref(), glucose({ value: 19 })));
    await assertFails(setDoc(ref(), glucose({ value: 98.5 })));
  });
  it('measured_at: not in the future, at most 31 days back', async () => {
    await seedAdult(env);
    const shift = (ms: number) => Timestamp.fromMillis(Date.now() + ms);
    const day = 24 * 60 * 60 * 1000;
    await assertSucceeds(setDoc(ref('a'), weight({ measured_at: shift(-30 * day) })));
    await assertFails(setDoc(ref(), weight({ measured_at: shift(60 * 60 * 1000) })));
    await assertFails(setDoc(ref(), weight({ measured_at: shift(-32 * day) })));
    await assertFails(setDoc(ref(), weight({ measured_at: '2026-10-14' })));
  });
  it('rejects bad ids and missing meta', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/metrics/a.b'), weight()));
    await assertFails(setDoc(ref('x'.repeat(41)), weight()));
    const { schema_version: _, ...noMeta } = weight();
    await assertFails(setDoc(ref(), noMeta));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), weight()));
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

describe('content_progress (Step 4e: where the person is in a lesson)', () => {
  const prog = (o: Record<string, unknown> = {}) => ({
    progress: 0.5, completed: false, ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/content_progress/lesson-1');

  it('owner saves and updates progress; nobody else; never deleted', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), prog()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), prog({ progress: 1, completed: true, created_at: saved.created_at, updated_at: meta().updated_at })),
    );
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/content_progress/lesson-1')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/content_progress/lesson-1'), prog()));
  });
  it('progress is 0..1, completed a bool, no other fields; meta required', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), prog({ progress: 1.5 })));
    await assertFails(setDoc(ref(), prog({ progress: -0.1 })));
    await assertFails(setDoc(ref(), prog({ completed: 'yes' })));
    await assertFails(setDoc(ref(), prog({ note: 'felt anxious' })));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/content_progress/a b'), prog()));
    const { schema_version: _, ...noMeta } = prog();
    await assertFails(setDoc(ref(), noMeta));
  });
  it('created_at never changes', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/content_progress/lesson-1': prog() });
    await assertFails(setDoc(ref(), prog({ created_at: meta().created_at, updated_at: meta().updated_at })));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), prog()));
  });
});

describe('rewards (T-GAM-01: badges earned and the chosen look, D-87)', () => {
  const rewards = (o: Record<string, unknown> = {}) => ({
    earned: { first_step: '2026-10-24' }, celebration: 'petals', ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/rewards/current');

  it('owner saves and adds badges; nobody else; never deleted', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), rewards()));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), rewards({
        earned: { first_step: '2026-10-24', restart: '2026-10-26' },
        created_at: saved.created_at, updated_at: meta().updated_at,
      })),
    );
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/rewards/current')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/rewards/current'), rewards()));
  });
  it('only the current doc, known celebration styles, no other fields; meta required', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/rewards/other'), rewards()));
    await assertFails(setDoc(ref(), rewards({ celebration: 'fireworks' })));
    await assertFails(setDoc(ref(), rewards({ earned: 'all' })));
    await assertFails(setDoc(ref(), rewards({ weight_lost: 2 })));
    const { schema_version: _, ...noMeta } = rewards();
    await assertFails(setDoc(ref(), noMeta));
  });
  it('created_at never changes', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/rewards/current': rewards() });
    await assertFails(setDoc(ref(), rewards({ created_at: meta().created_at, updated_at: meta().updated_at })));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), rewards()));
  });
});

describe('challenges (T-GAM-01: one weekly challenge, days only)', () => {
  const entry = (o: Record<string, unknown> = {}) => ({
    challenge_id: 'post_meal_walk', days: ['2026-10-26'], ...meta(), ...o,
  });
  const ref = () => doc(as(ALICE), 'users/alice/challenges/2026-10-26');

  it('owner joins and marks days; nobody else; never deleted', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(ref(), entry({ days: [] })));
    const saved = (await getDoc(ref())).data()!;
    await assertSucceeds(
      setDoc(ref(), entry({
        days: ['2026-10-26', '2026-10-27'],
        created_at: saved.created_at, updated_at: meta().updated_at,
      })),
    );
    await assertFails(deleteDoc(ref()));
    await assertFails(getDoc(doc(as(BOB), 'users/alice/challenges/2026-10-26')));
    await assertFails(setDoc(doc(as(BOB), 'users/alice/challenges/2026-10-26'), entry()));
  });
  it('known challenges only, at most 7 days, no amounts, a date id; meta required', async () => {
    await seedAdult(env);
    await assertFails(setDoc(ref(), entry({ challenge_id: 'lose_5_kg' })));
    await assertFails(setDoc(ref(), entry({ days: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'] })));
    await assertFails(setDoc(ref(), entry({ minutes: 60 })));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/challenges/this-week'), entry()));
    const { schema_version: _, ...noMeta } = entry();
    await assertFails(setDoc(ref(), noMeta));
  });
  it('the challenge and created_at never change', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/challenges/2026-10-26': entry() });
    const saved = (await getDoc(ref())).data()!;
    await assertFails(setDoc(ref(), entry({
      challenge_id: 'steady_bedtime', created_at: saved.created_at, updated_at: meta().updated_at,
    })));
    await assertFails(setDoc(ref(), entry({ created_at: meta().created_at, updated_at: meta().updated_at })));
  });
  it('nothing is stored before the 18+ gate', async () => {
    await assertFails(setDoc(ref(), entry()));
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
    await assertSucceeds(updateDoc(ref, { status: 'deleted', fact: '' }));
    await assertFails(updateDoc(ref, { status: 'saved' }));
  });
  it('deleting must wipe the text; saving must keep it (D-100)', async () => {
    const ref = doc(as(ALICE), 'users/alice/memory_facts/f1');
    await assertFails(updateDoc(ref, { status: 'deleted' }));
    await assertFails(updateDoc(ref, { status: 'deleted', fact: 'kept' }));
    await assertFails(updateDoc(ref, { status: 'saved', fact: '' }));
    await assertSucceeds(updateDoc(ref, { status: 'deleted', fact: '' }));
    await assertFails(updateDoc(ref, { fact: 'back again' }));
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
    'users/alice/data_exports/job1',
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

describe('data_exports (T-CMP-03: owner reads status, server writes)', () => {
  const job = () => ({ status: 'ready', counts: { checkins: 1 }, ...meta() });
  it('the owner reads and lists their jobs; nobody else can', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/data_exports/j1': job() });
    await assertSucceeds(getDoc(doc(as(ALICE), 'users/alice/data_exports/j1')));
    await assertSucceeds(
      getDocs(query(collection(as(ALICE), 'users/alice/data_exports'), orderBy('created_at', 'desc'), limit(1))),
    );
    await assertFails(getDoc(doc(as(BOB), 'users/alice/data_exports/j1')));
    await assertFails(getDocs(collection(as(BOB), 'users/alice/data_exports')));
    await assertFails(getDoc(doc(anon(), 'users/alice/data_exports/j1')));
  });
  it('the app can never create, change or delete a job', async () => {
    await seedAdult(env);
    await seed(env, { 'users/alice/data_exports/j1': job() });
    await assertFails(addDoc(collection(as(ALICE), 'users/alice/data_exports'), { status: 'preparing', ...meta() }));
    await assertFails(updateDoc(doc(as(ALICE), 'users/alice/data_exports/j1'), { status: 'ready' }));
    await assertFails(deleteDoc(doc(as(ALICE), 'users/alice/data_exports/j1')));
  });
});

describe('devices (T-TCH-01: push tokens, D-77)', () => {
  const path = 'users/alice/devices/AbCdEf0123456789XyZw';
  const device = (over: Record<string, unknown> = {}) => ({
    token: 'fcm-token-abc',
    platform: 'android',
    time_zone: 'America/New_York',
    ...serverMeta(),
    ...over,
  });
  it('owner registers a device: token, platform, time zone only', async () => {
    await seedAdult(env);
    await assertSucceeds(setDoc(doc(as(ALICE), path), device()));
    await assertSucceeds(getDoc(doc(as(ALICE), path)));
    // A new token replaces the old one.
    await assertSucceeds(setDoc(doc(as(ALICE), path), device({ token: 'fcm-token-new' })));
  });
  it('no personal fields, no unknown platform, no empty token', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), path), device({ display_name: 'Priya' })));
    await assertFails(setDoc(doc(as(ALICE), path), device({ email: 'p@example.com' })));
    await assertFails(setDoc(doc(as(ALICE), path), device({ platform: 'web' })));
    await assertFails(setDoc(doc(as(ALICE), path), device({ token: '' })));
    await assertFails(setDoc(doc(as(ALICE), path), device({ token: 'x'.repeat(4097) })));
    await assertFails(setDoc(doc(as(ALICE), path), device({ time_zone: 'x'.repeat(65) })));
    const { time_zone: _, ...noZone } = device();
    await assertFails(setDoc(doc(as(ALICE), path), noZone));
  });
  it('updated_at is the server time; the id is a plain install id', async () => {
    await seedAdult(env);
    await assertFails(setDoc(doc(as(ALICE), path), { ...device(), updated_at: meta().updated_at }));
    await assertFails(setDoc(doc(as(ALICE), 'users/alice/devices/short'), device()));
  });
  it('only the adult owner writes; others cannot read or write', async () => {
    await assertFails(setDoc(doc(as(ALICE), path), device())); // no profile yet
    await seedAdult(env);
    await assertFails(setDoc(doc(as(BOB), path), device()));
    await assertFails(setDoc(doc(anon(), path), device()));
    await seed(env, { [path]: { token: 't', platform: 'ios', time_zone: 'UTC', ...meta() } });
    await assertFails(getDoc(doc(as(BOB), path)));
    await assertFails(deleteDoc(doc(as(BOB), path)));
  });
  it('owner deletes it (consent off, log out)', async () => {
    await seedAdult(env);
    await seed(env, { [path]: { token: 't', platform: 'ios', time_zone: 'UTC', ...meta() } });
    await assertSucceeds(deleteDoc(doc(as(ALICE), path)));
  });
  it('push_days (the server daily count) is closed to the owner', async () => {
    await seedAdult(env);
    const day = 'users/alice/push_days/2026-11-16';
    await seed(env, { [day]: { count: 1, ...meta() } });
    await assertFails(getDoc(doc(as(ALICE), day)));
    await assertFails(setDoc(doc(as(ALICE), day), { count: 0, ...meta() }));
  });
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
  for (const col of [
    'voice_consents',
    'safety_events',
    'audit_log',
    'consent_revocations',
    'vendor_requests',
    'marketing_suppressions',
    'push_outbox',
  ]) {
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
  // T-FND-07 (D-83): copies of the prototype's users arrays are server-only
  // until the product decides how the app shows them.
  for (const col of ['legacy_goals', 'legacy_affirmations', 'legacy_favorites']) {
    it(`users/{uid}/${col} (T-FND-07 migration copies)`, async () => {
      await seed(env, { [`users/alice/${col}/0000`]: { index: 0, value: 'x', ...meta() } });
      await assertFails(getDoc(doc(as(ALICE), `users/alice/${col}/0000`)));
      await assertFails(setDoc(doc(as(ALICE), `users/alice/${col}/0001`), { index: 1, value: 'y', ...meta() }));
    });
  }
});

// ---------- portal catalog (T-PRT-02, D-92; spec 11.1) ----------
// App users read only live offers (active + approved); nobody writes from a
// client, staff included (the Admin uses the Core API); the workflow
// collection (staff ids) is server-only.
const asStaff = (uid: string) =>
  env
    .authenticatedContext(uid, {
      staff_roles: ['admin', 'content_editor', 'clinical_reviewer'],
      staff_mfa_waiver_until: Math.floor(Date.now() / 1000) + 3600,
    })
    .firestore();

const offer = (o: Record<string, unknown>) => ({
  title: 'Gut health in 30 days',
  url: 'https://livewell.conciergeconnectedcare.net/web/courses/gut-health',
  offer_type: 'course',
  driver_tags: [],
  topic_tags: [],
  price_display: '$49',
  version: 1,
  ...meta(),
  ...o,
});

async function seedOffers() {
  await seed(env, {
    'portal_offers/live': offer({ active: true, review_status: 'approved' }),
    'portal_offers/approved_not_live': offer({ active: false, review_status: 'approved' }),
    'portal_offers/draft': offer({ active: false, review_status: 'draft' }),
    'portal_offers/in_review': offer({ active: false, review_status: 'in_review' }),
    'portal_offers/rejected': offer({ active: false, review_status: 'rejected' }),
    'portal_offers/archived': offer({ active: false, review_status: 'archived' }),
    // Inconsistent states the API never writes, still hidden.
    'portal_offers/archived_active': offer({ active: true, review_status: 'archived' }),
    'portal_offers/draft_active': offer({ active: true, review_status: 'draft' }),
    'portal_offers/active_string': offer({ active: 'true', review_status: 'approved' }),
    'portal_offer_workflow/live': { rev: 3, created_by: 'staff1', version_editors: [], ...meta() },
  });
}

describe('portal_offers: clients see live offers only (T-PRT-02, D-92)', () => {
  beforeEach(seedOffers);
  it('a signed-in user reads only the active + approved offer', async () => {
    await assertSucceeds(getDoc(doc(as(ALICE), 'portal_offers/live')));
    for (const id of [
      'approved_not_live',
      'draft',
      'in_review',
      'rejected',
      'archived',
      'archived_active',
      'draft_active',
      'active_string',
    ]) {
      await assertFails(getDoc(doc(as(ALICE), `portal_offers/${id}`)));
    }
  });

  it("the app's filtered query works; an unfiltered list is refused", async () => {
    const q = query(
      collection(as(ALICE), 'portal_offers'),
      where('active', '==', true),
      where('review_status', '==', 'approved'),
    );
    await assertSucceeds(getDocs(q));
    await assertFails(getDocs(collection(as(ALICE), 'portal_offers')));
    await assertFails(getDocs(query(collection(as(ALICE), 'portal_offers'), where('active', '==', true))));
  });

  it('signed-out readers see nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'portal_offers/live')));
  });

  it('staff claims give no extra client access: reads and writes go through the Core API', async () => {
    const staff = asStaff('staff1');
    await assertSucceeds(getDoc(doc(staff, 'portal_offers/live')));
    await assertFails(getDoc(doc(staff, 'portal_offers/draft')));
    await assertFails(setDoc(doc(staff, 'portal_offers/new'), offer({ active: false, review_status: 'draft' })));
    await assertFails(updateDoc(doc(staff, 'portal_offers/live'), { title: 'Changed' }));
    await assertFails(updateDoc(doc(staff, 'portal_offers/draft'), { active: true, review_status: 'approved' }));
    await assertFails(deleteDoc(doc(staff, 'portal_offers/live')));
  });

  it('app users cannot create, publish, edit or delete offers', async () => {
    const db = as(ALICE);
    await assertFails(setDoc(doc(db, 'portal_offers/new'), offer({ active: true, review_status: 'approved' })));
    await assertFails(updateDoc(doc(db, 'portal_offers/live'), { price_display: '$1' }));
    await assertFails(deleteDoc(doc(db, 'portal_offers/live')));
  });
});

describe('portal_offer_workflow: server-only (D-92)', () => {
  beforeEach(seedOffers);
  it('nobody reads or writes it from a client', async () => {
    for (const db of [as(ALICE), asStaff('staff1'), anon()]) {
      await assertFails(getDoc(doc(db, 'portal_offer_workflow/live')));
      await assertFails(setDoc(doc(db, 'portal_offer_workflow/x'), { rev: 1 }));
      await assertFails(updateDoc(doc(db, 'portal_offer_workflow/live'), { version_editors: [] }));
    }
  });
});
