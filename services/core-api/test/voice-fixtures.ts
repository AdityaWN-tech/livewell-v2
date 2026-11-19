import { getFirestore, Timestamp } from 'firebase-admin/firestore';

import type { AuditEntry, AuditLog } from '../src/audit/audit-log.js';
import type { GatewayConfig } from '../src/voice/gateway.js';
import type { ScriptBundle } from '../src/voice/scripts.js';
import type { TtsAdapter } from '../src/voice/tts-adapter.js';

/** Fixture scripts (the real content is still pending clinical review). */
export const fixtureScripts: ScriptBundle = {
  moments: {
    hello: {
      version: 2,
      review_status: 'approved',
      variants: {
        a: 'One small step today.',
        n: 'Hi {first_name}, one small step today.',
        m: 'Even {smaller_minutes} minutes counts this {time_of_day}.',
        w: 'You made time for {routine_win} on {routine_win_days} days.',
        z: 'Hi {mystery}.',
      },
    },
    pending_file: { version: 1, review_status: 'pending', variants: { a: 'A pending line.' } },
  },
  routine: {
    version: 1,
    review_status: 'approved',
    lines: {
      'wake_up.w1': "It's {time}. Time to stretch your arms.",
      'custom.c1': "Time for your next routine step.",
    },
    spoken_names: { wake_up: 'an easy start to your day' },
  },
};

export const allOn: GatewayConfig = { clonedVoicesEnabled: true, gokulaVoiceEnabled: false };

/** Records what it was asked to say; returns a few bytes. */
export class FakeTts implements TtsAdapter {
  calls: { vendorVoiceId: string; text: string; speed: number }[] = [];
  async synthesize(req: { vendorVoiceId: string; text: string; speed: number }) {
    this.calls.push(req);
    return { audio: Buffer.from('fake-audio'), mime: 'audio/mpeg' };
  }
}

/** Keeps entries in memory (the Firestore writer is tested separately). */
export class MemoryAuditLog implements AuditLog {
  entries: (AuditEntry & { id: string })[] = [];
  async append(id: string, entry: AuditEntry) {
    this.entries.push({ id, ...entry });
  }
}

const meta = () => ({ created_at: Timestamp.now(), updated_at: Timestamp.now(), schema_version: 1 });

export const newUid = () => `vg_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;

/** Seeds one account's voices, consents and messages, plus shared lessons. */
export async function seed(uid: string) {
  const db = getFirestore();
  const consent = (over: Record<string, unknown>) => ({
    account_uid: uid,
    voice_owner_name: 'Fixture Owner',
    consent_text_version: 'voice-consent-1.0',
    permitted_use: `coaching_messages_in_account_${uid}_only`,
    status: 'active',
    revoked_at: null,
    revoked_by: null,
    ...over,
  });
  const voice = (over: Record<string, unknown>) => ({
    vendor_voice_id: 'vendor-x',
    status: 'active',
    speed: 1,
    style: 'calm',
    ...meta(),
    ...over,
  });
  const writes: [string, Record<string, unknown>][] = [
    [`voice_consents/vc_ok_${uid}`, consent({})],
    [`voice_consents/vc_rev_${uid}`, consent({ status: 'revoked', revoked_at: Timestamp.now(), revoked_by: 'owner' })],
    [`voice_consents/vc_other_${uid}`, consent({ account_uid: 'someone_else', permitted_use: 'coaching_messages_in_account_someone_else_only' })],
    [`users/${uid}/voices/lw-warm`, voice({ kind: 'library' })],
    [`users/${uid}/voices/lw-old`, voice({ kind: 'library', status: 'inactive' })],
    [`users/${uid}/voices/clone-self`, voice({ kind: 'self_clone', consent_id: `vc_ok_${uid}`, speed: 0.9 })],
    [`users/${uid}/voices/clone-revoked`, voice({ kind: 'loved_one', consent_id: `vc_rev_${uid}` })],
    [`users/${uid}/voices/clone-voice-revoked`, voice({ kind: 'loved_one', consent_id: `vc_ok_${uid}`, status: 'revoked' })],
    [`users/${uid}/voices/clone-noconsent`, voice({ kind: 'loved_one' })],
    [`users/${uid}/voices/clone-other-account`, voice({ kind: 'loved_one', consent_id: `vc_other_${uid}` })],
    [`users/${uid}/voices/gokula`, voice({ kind: 'gokula' })],
    [`users/${uid}/voices/weird-kind`, voice({ kind: 'custom_upload' })],
    [`users/someone_else/voices/not-mine`, voice({ kind: 'library' })],
    [`users/${uid}/messages/msg_approved_1`, { text: "Let's take a short walk after lunch.", contains_user_text: false, safety: { status: 'approved', checks: ['med_rule'] }, ...meta() }],
    [`users/${uid}/messages/msg_with_name_1`, { text: 'Good morning, Priya.', contains_user_text: true, safety: { status: 'approved' }, ...meta() }],
    [`users/${uid}/messages/msg_unchecked_1`, { text: 'Not checked yet.', contains_user_text: false, safety: { status: 'pending' }, ...meta() }],
    [`users/${uid}/messages/msg_crisis_0001`, { text: 'Crisis template.', contains_user_text: false, safety: { status: 'approved', category: 'CRISIS' }, ...meta() }],
    [`users/${uid}/messages/msg_medb_00001`, { text: 'Medical boundary.', contains_user_text: false, safety: { status: 'approved', category: 'MED_BOUNDARY' }, ...meta() }],
    ['content_items/les_1', { type: 'lesson', review_status: 'approved', version: 3, cards: ['Card one.', 'Card two.'], microhabit: { title: 'Walk for 5 minutes', minutes: 5 }, ...meta() }],
    ['content_items/les_pending', { type: 'lesson', review_status: 'in_review', version: 1, cards: ['Draft.'], ...meta() }],
  ];
  await Promise.all(writes.map(([p, d]) => db.doc(p).set(d)));
}
