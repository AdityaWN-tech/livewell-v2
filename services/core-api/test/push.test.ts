import { readFileSync } from 'node:fs';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import type { TokenMessage } from 'firebase-admin/messaging';
import { beforeAll, describe, expect, it } from 'vitest';

import { PUSH_CATEGORIES, PUSH_COPY, type PushCategory } from '../src/push/copy.js';
import {
  categoryOff,
  inQuietHours,
  localReserve,
  localTime,
  notificationsGranted,
} from '../src/push/policy.js';
import { buildMessage, sendPush } from '../src/push/send-push.js';
import type { PushTransport, SendResult } from '../src/push/transport.js';

// Runs inside `firebase emulators:exec` (npm test): the Admin SDK talks to
// the Firestore emulator. Only the FCM send is replaced (FakeTransport);
// consent, toggles, quiet hours, the cap and token cleanup are the real code
// against real (emulated) documents.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell' });
});

const db = () => getFirestore();

// ---------- the mock boundary: FCM ----------

/**
 * Stands in for FcmTransport, the only code that talks to FCM. Records
 * what would have been sent; [fail] makes chosen tokens fail with an FCM
 * error code.
 */
class FakeTransport implements PushTransport {
  sent: TokenMessage[] = [];
  fail = new Map<string, string>();
  async send(messages: TokenMessage[]): Promise<SendResult[]> {
    this.sent.push(...messages);
    return messages.map((m) => {
      const code = this.fail.get(m.token);
      return code ? { ok: false, code } : { ok: true };
    });
  }
}

// Monday 16 Nov 2026, 12:00 in New York (EST, UTC-5).
const NOON_NY = new Date('2026-11-16T17:00:00Z');
const at = (iso: string) => () => new Date(iso);

let n = 0;
const newUid = () => `push-${Date.now().toString(36)}-${n++}`;

/** Things that must never reach a notification (PHI, free text). */
const PRIVATE = {
  display_name: 'Priya Sharma',
  why_statement: 'Bring my glucose down from 182 for my daughter',
  email: 'priya@example.com',
};

async function seedUser(
  opts: {
    consent?: boolean | null;
    profile?: Record<string, unknown>;
    devices?: Record<string, { token: string; time_zone?: string }>;
  } = {},
) {
  const uid = newUid();
  const now = Timestamp.now();
  const meta = { created_at: now, updated_at: now, schema_version: 1 };
  await db()
    .doc(`users/${uid}`)
    .set({ ...PRIVATE, age_confirmed: true, tz: 'America/New_York', ...meta, ...opts.profile });
  if (opts.consent !== null) {
    await db()
      .collection(`users/${uid}/consents`)
      .add({
        type: 'notifications',
        doc_version: 'notifications-0.1-draft',
        granted: opts.consent ?? true,
        app_version: '1.0.0',
        ...meta,
      });
  }
  const devices = opts.devices ?? { phone1: { token: `tok-${Math.random().toString(36).slice(2)}` } };
  for (const [id, d] of Object.entries(devices)) {
    await db()
      .doc(`users/${uid}/devices/${id}`)
      .set({ platform: 'android', time_zone: 'America/New_York', ...d, ...meta });
  }
  return uid;
}

/** All touchpoint toggles off: no local reserve, so the full 4 are the server's. */
const NO_LOCAL = {
  notification_categories: { greeting: false, nudge: false, reflection: false },
};

describe('policy (pure)', () => {
  it('local time, date and weekday in the person zone', () => {
    expect(localTime(NOON_NY, 'America/New_York')).toEqual({
      date: '2026-11-16',
      minutes: 12 * 60,
      weekday: 1,
    });
    // 22:30 in Kolkata is already the next local day there.
    expect(localTime(new Date('2026-11-16T17:00:00Z'), 'Asia/Kolkata').date).toBe('2026-11-16');
    expect(localTime(new Date('2026-11-16T19:00:00Z'), 'Asia/Kolkata').date).toBe('2026-11-17');
  });

  it('quiet hours: default 22:00–07:00, across midnight, custom', () => {
    expect(inQuietHours(23 * 60, undefined)).toBe(true);
    expect(inQuietHours(6 * 60 + 59, undefined)).toBe(true);
    expect(inQuietHours(7 * 60, undefined)).toBe(false);
    expect(inQuietHours(12 * 60, { start: '12:00', end: '13:00' })).toBe(true);
    expect(inQuietHours(13 * 60, { start: '12:00', end: '13:00' })).toBe(false);
  });

  it('category toggles: off only when set to false; coach notices have none', () => {
    expect(categoryOff('nudge', { nudge: false })).toBe(true);
    expect(categoryOff('nudge', {})).toBe(false);
    expect(categoryOff('coach_ready', { greeting: false, nudge: false })).toBe(false);
  });

  it('consent: newest record wins; none means no', () => {
    const t = (ms: number) => ({ toMillis: () => ms });
    expect(notificationsGranted([])).toBe(false);
    expect(
      notificationsGranted([
        { type: 'notifications', granted: true, created_at: t(1) },
        { type: 'notifications', granted: false, created_at: t(2) },
      ]),
    ).toBe(false);
    expect(
      notificationsGranted([
        { type: 'notifications', granted: false, created_at: t(1) },
        { type: 'notifications', granted: true, created_at: t(2) },
        { type: 'marketing', granted: false, created_at: t(3) },
      ]),
    ).toBe(true);
  });

  it('local reserve assumes every enabled local reminder fires', () => {
    const base = { toggles: {}, routineRemindersPerDay: undefined, routineItemsWithReminder: 0 };
    expect(localReserve({ ...base, weekday: 1 }).total).toBe(3);
    expect(localReserve({ ...base, weekday: 7 }).total).toBe(4);
    expect(localReserve({ ...base, toggles: NO_LOCAL.notification_categories, weekday: 1 }).total).toBe(0);
    expect(localReserve({ ...base, weekday: 1, routineItemsWithReminder: 2 }).total).toBe(5);
    expect(
      localReserve({ ...base, weekday: 1, routineRemindersPerDay: 0, routineItemsWithReminder: 5 })
        .total,
    ).toBe(3);
  });
});

describe('no PHI on the lock screen (FR-TCH-02)', () => {
  it('copy is fixed, generic text, the same as the app shows', () => {
    const arb = JSON.parse(
      readFileSync(new URL('../../../apps/mobile/lib/l10n/app_en.arb', import.meta.url), 'utf8'),
    ) as Record<string, string>;
    const app: Record<PushCategory, [string, string]> = {
      greeting: [arb.reminderGreetingTitle!, arb.reminderGreetingBody!],
      nudge: [arb.reminderNudgeTitle!, arb.reminderNudgeBody!],
      reflection: [arb.reminderReflectionTitle!, arb.reminderReflectionBody!],
      weekly: [arb.reminderWeeklyTitle!, arb.reminderWeeklyBody!],
      coach_ready: [arb.coachNoticeReadyTitle!, arb.coachNoticeReadyBody!],
      coach_not_made: [arb.coachNoticeNotMadeTitle!, arb.coachNoticeNotMadeBody!],
    };
    for (const c of PUSH_CATEGORIES) {
      expect([PUSH_COPY[c].title, PUSH_COPY[c].body]).toEqual(app[c]);
      // No placeholders and no numbers: nothing can be filled in.
      expect(`${PUSH_COPY[c].title} ${PUSH_COPY[c].body}`).not.toMatch(/[{}$%<>\d]/);
    }
  });

  it('a message carries only the fixed words, the category and a plain ID', () => {
    const m = buildMessage('tok', 'nudge', 'job_123');
    expect(m.notification).toEqual({ title: PUSH_COPY.nudge.title, body: PUSH_COPY.nudge.body });
    expect(m.data).toEqual({ category: 'nudge', ref_id: 'job_123' });
    expect(m.android?.notification?.visibility).toBe('private');
    // Free text can't ride along as an "ID".
    expect(buildMessage('tok', 'nudge', 'glucose 182 mg/dL').data).toEqual({ category: 'nudge' });
  });

  it('nothing from the profile reaches FCM', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ profile: NO_LOCAL });
    const r = await sendPush({ uid, category: 'coach_ready', refId: 'job1' }, { transport: t, now: () => NOON_NY });
    expect(r.status).toBe('sent');
    const wire = JSON.stringify(t.sent);
    for (const v of Object.values(PRIVATE)) expect(wire).not.toContain(v);
    expect(wire).not.toContain(uid);
    expect(Object.keys(t.sent[0]!.data!).sort()).toEqual(['category', 'ref_id']);
  });
});

describe('sendPush (Firestore emulator, FCM faked)', () => {
  it('consent never given → nothing sent', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ consent: null, profile: NO_LOCAL });
    const r = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(r).toEqual({ status: 'skipped', reason: 'no_consent', removed: 0 });
    expect(t.sent).toEqual([]);
  });

  it('consent revoked (newer record) → nothing sent', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ consent: true, profile: NO_LOCAL });
    await new Promise((r) => setTimeout(r, 5));
    await db().collection(`users/${uid}/consents`).add({
      type: 'notifications',
      granted: false,
      doc_version: 'v',
      app_version: '1',
      created_at: Timestamp.now(),
      updated_at: Timestamp.now(),
      schema_version: 1,
    });
    const r = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(r.status === 'skipped' && r.reason).toBe('no_consent');
    expect(t.sent).toEqual([]);
  });

  it('category toggled off → nothing sent; other categories still go', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ profile: { notification_categories: { greeting: true, nudge: false, reflection: true } } });
    const off = await sendPush({ uid, category: 'nudge' }, { transport: t, now: () => NOON_NY });
    expect(off.status === 'skipped' && off.reason).toBe('category_off');
    expect(t.sent).toEqual([]);
    const on = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(on.status).toBe('sent');
  });

  it('quiet hours (default and the person own) → nothing sent', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ profile: NO_LOCAL });
    // 23:30 in New York.
    const late = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: at('2026-11-17T04:30:00Z') });
    expect(late.status === 'skipped' && late.reason).toBe('quiet_hours');
    const uid2 = await seedUser({ profile: { ...NO_LOCAL, quiet_hours: { start: '11:00', end: '14:00' } } });
    const noon = await sendPush({ uid: uid2, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(noon.status === 'skipped' && noon.reason).toBe('quiet_hours');
    expect(t.sent).toEqual([]);
  });

  it('daily cap of 4 per local day, and a new local day starts again', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ profile: NO_LOCAL });
    const now = () => NOON_NY;
    for (let i = 0; i < 4; i++) {
      expect((await sendPush({ uid, category: 'coach_ready' }, { transport: t, now })).status).toBe('sent');
    }
    const fifth = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now });
    expect(fifth.status === 'skipped' && fifth.reason).toBe('daily_cap');
    expect(t.sent).toHaveLength(4);
    expect((await db().doc(`users/${uid}/push_days/2026-11-16`).get()).get('count')).toBe(4);
    const tomorrow = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: at('2026-11-17T17:00:00Z') });
    expect(tomorrow.status).toBe('sent');
  });

  it('the phone local reminders count toward the 4 (conservative reserve)', async () => {
    const t = new FakeTransport();
    // All 3 daily touchpoints on: 1 left for the server on a weekday.
    const uid = await seedUser();
    expect((await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY })).status).toBe('sent');
    const second = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(second.status === 'skipped' && second.reason).toBe('daily_cap');
    // Sunday adds the weekly review: nothing left.
    const sunday = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: at('2026-11-22T17:00:00Z') });
    expect(sunday.status === 'skipped' && sunday.reason).toBe('daily_cap');
    // Routine reminders fill the day too.
    const uid2 = await seedUser({ profile: NO_LOCAL });
    for (const id of ['r1', 'r2', 'r3', 'r4']) {
      await db().doc(`users/${uid2}/routine_items/${id}`).set({ reminder: true, time: '09:00' });
    }
    const routine = await sendPush({ uid: uid2, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(routine.status === 'skipped' && routine.reason).toBe('daily_cap');
    expect(t.sent).toHaveLength(1);
  });

  it('invalid tokens are removed; valid devices still get it', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({
      profile: NO_LOCAL,
      devices: { old: { token: 'stale' }, phone: { token: 'good' } },
    });
    t.fail.set('stale', 'messaging/registration-token-not-registered');
    const r = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(r).toEqual({ status: 'sent', sent: 1, removed: 1 });
    expect((await db().doc(`users/${uid}/devices/old`).get()).exists).toBe(false);
    expect((await db().doc(`users/${uid}/devices/phone`).get()).exists).toBe(true);
  });

  it('nothing delivered → the slot is given back; a temporary error keeps the device', async () => {
    const t = new FakeTransport();
    const uid = await seedUser({ profile: NO_LOCAL, devices: { phone: { token: 'busy' } } });
    t.fail.set('busy', 'messaging/internal-error');
    const r = await sendPush({ uid, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(r).toEqual({ status: 'skipped', reason: 'not_delivered', removed: 0 });
    expect((await db().doc(`users/${uid}/push_days/2026-11-16`).get()).get('count')).toBe(0);
    expect((await db().doc(`users/${uid}/devices/phone`).get()).exists).toBe(true);
  });

  it('no device or no usable time zone → nothing sent', async () => {
    const t = new FakeTransport();
    const none = await seedUser({ profile: NO_LOCAL, devices: {} });
    const r1 = await sendPush({ uid: none, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(r1.status === 'skipped' && r1.reason).toBe('no_devices');
    const noZone = await seedUser({
      profile: { ...NO_LOCAL, tz: 'Not/AZone' },
      devices: { phone: { token: 't', time_zone: 'Mars/Base' } },
    });
    const r2 = await sendPush({ uid: noZone, category: 'coach_ready' }, { transport: t, now: () => NOON_NY });
    expect(r2.status === 'skipped' && r2.reason).toBe('no_time_zone');
    expect(t.sent).toEqual([]);
  });

  it('nudges keep to 3 a day (FR-DLY-04)', async () => {
    const t = new FakeTransport();
    // Only the midday nudge on locally: 1 local nudge reserved.
    const uid = await seedUser({ profile: { notification_categories: { greeting: false, nudge: true, reflection: false } } });
    const now = () => NOON_NY;
    expect((await sendPush({ uid, category: 'nudge' }, { transport: t, now })).status).toBe('sent');
    expect((await sendPush({ uid, category: 'nudge' }, { transport: t, now })).status).toBe('sent');
    const third = await sendPush({ uid, category: 'nudge' }, { transport: t, now });
    expect(third.status === 'skipped' && third.reason).toBe('nudge_cap');
  });
});

async function waitForField(path: string, field: string, timeoutMs = 15_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const snap = await db().doc(path).get();
    if (snap.get(field) !== undefined) return snap.data()!;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timed out waiting for ${path}.${field}`);
}

describe('onPushRequest trigger (functions emulator)', () => {
  // The deployed trigger uses the real FcmTransport, so these cases stop
  // before any send: no request in these tests reaches FCM.
  it('runs every check: without consent nothing is sent', async () => {
    const uid = await seedUser({ consent: null });
    const ref = await db().collection('push_outbox').add({ uid, category: 'coach_ready', ref_id: 'job9' });
    const doc = await waitForField(ref.path, 'result');
    expect(doc.result).toEqual({ status: 'skipped', reason: 'no_consent', removed: 0 });
    expect(doc.expire_at).toBeInstanceOf(Timestamp);
  });

  it('rejects a request with free text or an unknown category', async () => {
    const ref = await db().collection('push_outbox').add({ uid: 'u1', category: 'glucose_alert' });
    expect((await waitForField(ref.path, 'result')).result).toEqual({ status: 'invalid' });
    const ref2 = await db()
      .collection('push_outbox')
      .add({ uid: 'u1', category: 'nudge', ref_id: 'your glucose is 182' });
    expect((await waitForField(ref2.path, 'result')).result).toEqual({ status: 'invalid' });
  });
});
