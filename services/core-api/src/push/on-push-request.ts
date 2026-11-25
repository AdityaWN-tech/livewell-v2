import { Timestamp } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { z } from 'zod';

import { PUSH_CATEGORIES } from './copy.js';
import { sendPush, type PushOutcome } from './send-push.js';
import { FcmTransport, type PushTransport } from './transport.js';

/**
 * A push request from another server (the Media Service's JobNotifier when
 * a coach is made; later the nudge scheduler and briefing jobs). Only a
 * uid, a category and an ID: the words are chosen here from fixed copy.
 */
export const PushRequestSchema = z
  .object({
    uid: z.string().min(1).max(128),
    category: z.enum(PUSH_CATEGORIES),
    ref_id: z
      .string()
      .regex(/^[A-Za-z0-9_-]{1,64}$/)
      .optional(),
  })
  .strip();

/** How long a processed request is kept (Firestore TTL on expire_at). */
const KEEP_DAYS = 7;

/** What the request document records: the outcome only, no content. */
export function outcomeFields(outcome: PushOutcome | { status: 'invalid' }, now: Date) {
  return {
    result: outcome,
    processed_at: Timestamp.fromDate(now),
    expire_at: Timestamp.fromMillis(now.getTime() + KEEP_DAYS * 86_400_000),
  };
}

/**
 * push_outbox/{id} (server-only, closed to clients by firestore.rules):
 * each new document is one push request, sent through [sendPush] with
 * every check (consent, category, quiet hours, daily cap).
 */
export function makeOnPushRequest(transport: PushTransport = new FcmTransport()) {
  return onDocumentCreated('push_outbox/{requestId}', async (event) => {
    const snap = event.data;
    if (!snap) return;
    const now = new Date();
    const parsed = PushRequestSchema.safeParse(snap.data());
    if (!parsed.success) {
      await snap.ref.update(outcomeFields({ status: 'invalid' }, now));
      return;
    }
    const { uid, category, ref_id } = parsed.data;
    const outcome = await sendPush({ uid, category, refId: ref_id }, { transport });
    await snap.ref.update(outcomeFields(outcome, now));
  });
}
