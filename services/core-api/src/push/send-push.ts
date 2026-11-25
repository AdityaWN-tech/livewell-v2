import {
  FieldValue,
  getFirestore,
  Timestamp,
  type DocumentReference,
  type Firestore,
} from 'firebase-admin/firestore';
import type { TokenMessage } from 'firebase-admin/messaging';

import { PUSH_COPY, type PushCategory } from './copy.js';
import {
  categoryOff,
  DAILY_CAP,
  inQuietHours,
  isTimeZone,
  localReserve,
  localTime,
  notificationsGranted,
  NUDGE_CAP,
  safeRefId,
} from './policy.js';
import { INVALID_TOKEN_CODES, type PushTransport } from './transport.js';

export type SkipReason =
  | 'no_consent'
  | 'category_off'
  | 'no_devices'
  | 'no_time_zone'
  | 'quiet_hours'
  | 'daily_cap'
  | 'nudge_cap'
  | 'not_delivered';

export type PushOutcome =
  | { status: 'sent'; sent: number; removed: number }
  | { status: 'skipped'; reason: SkipReason; removed: number };

export interface PushRequest {
  uid: string;
  category: PushCategory;
  /** An ID to deep-link to (a job id, a date); never free text. */
  refId?: string;
}

export interface PushDeps {
  transport: PushTransport;
  now?: () => Date;
  db?: Firestore;
}

/**
 * The FCM message for one device. Only the category's fixed words and
 * `data: {category, ref_id}`; the person's data never reaches this
 * function. Android keeps even these words off a locked screen
 * (visibility private), like the app's local reminders.
 */
export function buildMessage(token: string, category: PushCategory, refId?: string): TokenMessage {
  const copy = PUSH_COPY[category];
  const ref = safeRefId(refId);
  return {
    token,
    notification: { title: copy.title, body: copy.body },
    data: ref === undefined ? { category } : { category, ref_id: ref },
    android: {
      priority: 'normal',
      notification: { channelId: copy.channel, visibility: 'private', tag: category },
    },
    apns: { payload: { aps: { threadId: category } } },
  };
}

const skip = (reason: SkipReason, removed = 0): PushOutcome => ({
  status: 'skipped',
  reason,
  removed,
});

/**
 * Sends one push to every device of [uid] (T-TCH-01, FR-TCH-01/02, D-77),
 * only when all of these hold:
 * 1. the newest notifications consent record grants it;
 * 2. the category's toggle (Profile > Daily plan) is not off;
 * 3. it is not quiet hours in the person's time zone (no deferral: a push
 *    that would land in quiet hours is dropped; the app shows the news on
 *    the next open);
 * 4. today's cap of 4 (local day) is not reached, counting this server's
 *    sends in users/{uid}/push_days/{date} plus a conservative reserve for
 *    the phone's own local notifications ([localReserve]); nudges also
 *    keep to 3 a day.
 * Tokens FCM reports as invalid are removed.
 */
export async function sendPush(req: PushRequest, deps: PushDeps): Promise<PushOutcome> {
  const db = deps.db ?? getFirestore();
  const now = (deps.now ?? (() => new Date()))();
  const user = db.doc(`users/${req.uid}`);

  const consents = await user.collection('consents').where('type', '==', 'notifications').get();
  if (!notificationsGranted(consents.docs.map((d) => d.data()))) return skip('no_consent');

  const profile = (await user.get()).data() ?? {};
  if (categoryOff(req.category, profile.notification_categories)) return skip('category_off');

  const devices = (await user.collection('devices').get()).docs.filter(
    (d) => typeof d.get('token') === 'string' && d.get('token') !== '',
  );
  if (devices.length === 0) return skip('no_devices');

  // The newest device's zone (the phone travels with the person), else the profile's.
  const newest = [...devices].sort(
    (a, b) =>
      (b.get('updated_at')?.toMillis?.() ?? 0) - (a.get('updated_at')?.toMillis?.() ?? 0),
  );
  const tz =
    newest.map((d) => d.get('time_zone')).find(isTimeZone) ??
    (isTimeZone(profile.tz) ? profile.tz : undefined);
  // Without a zone, quiet hours and the local day are unknown: don't send.
  if (tz === undefined) return skip('no_time_zone');

  const local = localTime(now, tz);
  if (inQuietHours(local.minutes, profile.quiet_hours)) return skip('quiet_hours');

  const perDay = profile.routine_reminders_per_day;
  const routineItems =
    perDay === 0
      ? 0
      : (await user.collection('routine_items').where('reminder', '==', true).count().get()).data()
          .count;
  const reserve = localReserve({
    toggles: profile.notification_categories,
    weekday: local.weekday,
    routineRemindersPerDay: perDay,
    routineItemsWithReminder: routineItems,
  });

  const isNudge = req.category === 'nudge';
  const day = user.collection('push_days').doc(local.date);
  const reserved = await db.runTransaction(async (tx) => {
    const snap = await tx.get(day);
    const count = (snap.get('count') as number | undefined) ?? 0;
    const nudges = (snap.get('nudges') as number | undefined) ?? 0;
    if (reserve.total + count >= DAILY_CAP) return 'daily_cap' as const;
    if (isNudge && reserve.nudges + nudges >= NUDGE_CAP) return 'nudge_cap' as const;
    const stamp = Timestamp.fromDate(now);
    tx.set(day, {
      count: count + 1,
      nudges: nudges + (isNudge ? 1 : 0),
      created_at: snap.exists ? snap.get('created_at') : stamp,
      updated_at: stamp,
      schema_version: 1,
    });
    return 'ok' as const;
  });
  if (reserved !== 'ok') return skip(reserved);

  const results = await deps.transport.send(
    devices.map((d) => buildMessage(d.get('token') as string, req.category, req.refId)),
  );
  let sent = 0;
  const invalid: DocumentReference[] = [];
  for (const [i, r] of results.entries()) {
    if (r.ok) sent++;
    else if (INVALID_TOKEN_CODES.has(r.code)) invalid.push(devices[i]!.ref);
  }
  await Promise.all(invalid.map((ref) => ref.delete()));

  if (sent === 0) {
    // Nothing arrived: give the slot back.
    await day.update({
      count: FieldValue.increment(-1),
      nudges: FieldValue.increment(isNudge ? -1 : 0),
    });
    return skip('not_delivered', invalid.length);
  }
  return { status: 'sent', sent, removed: invalid.length };
}
