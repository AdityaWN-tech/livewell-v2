import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { z } from 'zod';

import type { AuditLog } from '../audit/audit-log.js';
import { render, type Params } from './placeholders.js';
import {
  lookupBundled,
  parseMessageId,
  type Lookup,
  type ParsedMessageId,
  type ScriptBundle,
} from './scripts.js';
import type { TtsAdapter } from './tts-adapter.js';

/**
 * The closed-script voice gateway (T-VOC-07, FR-VOC-05, FR-VOC-07).
 *
 * The one server entry point for speech in a coach voice. It takes a
 * `message_id` and a `voice_id`, never text: it looks the approved,
 * versioned text up itself, checks the voice and (for cloned or licensed
 * voices) the owner's consent, and only then calls the TTS adapter. Every
 * refusal, every synthesis and every safety routing is audited with ids and
 * counts only (no text, spec 16.3).
 *
 * Safety, crisis and medical-boundary messages are never spoken by a coach
 * voice: the gateway answers `neutral_device` (speak with the phone's
 * neutral voice) without reading anything, so it can never block or slow
 * safety routing. The app's safety cards don't call the gateway at all:
 * they are plain code with fixed text (AGENTS.md, FR-SAF-02).
 */

/** Why a request was refused. Stable codes; the app maps them to nothing
 * more than "play the text" (FR-AVT-05). */
export type RefusalReason =
  | 'free_text_refused'
  | 'bad_request'
  | 'unknown_message'
  | 'retired_message'
  | 'not_approved'
  | 'user_text_not_allowed'
  | 'bad_params'
  | 'unknown_placeholder'
  | 'unknown_voice'
  | 'voice_inactive'
  | 'unsupported_voice_kind'
  | 'cloned_voices_off'
  | 'gokula_voice_off'
  | 'consent_missing'
  | 'consent_revoked'
  | 'consent_wrong_account'
  | 'tts_unavailable';

export class GatewayRefusal extends Error {
  constructor(readonly reason: RefusalReason) {
    super(reason);
  }
}

export type VoiceKind = 'library' | 'cloned' | 'licensed';

export type GatewayResult =
  | {
      status: 'ok';
      message_id: string;
      voice_kind: VoiceKind;
      /** FR-VOC-08: cloned and licensed voices show the "AI voice" label. */
      ai_voice_label: boolean;
      mime: string;
      audio_base64: string;
    }
  | {
      /** FR-VOC-07: speak this with the phone's neutral voice, or show it. */
      status: 'neutral_device';
      message_id: string;
    };

/** Kill switches (spec 16 "kill switches for each risky capability").
 * Both default to off; see D-88. */
export interface GatewayConfig {
  clonedVoicesEnabled: boolean;
  gokulaVoiceEnabled: boolean;
}

export function configFromEnv(env: NodeJS.ProcessEnv = process.env): GatewayConfig {
  return {
    clonedVoicesEnabled: env.LW_CLONED_VOICES_ENABLED === 'true',
    gokulaVoiceEnabled: env.LW_GOKULA_VOICE_ENABLED === 'true',
  };
}

export interface GatewayDeps {
  scripts: ScriptBundle;
  tts: TtsAdapter;
  log: AuditLog;
  config: GatewayConfig;
  db?: () => Firestore;
}

/** Keys that would carry words to speak. Refused by name, so the audit
 * log shows the attempt (the rest are refused as bad_request). */
const FREE_TEXT_KEYS = ['text', 'ssml', 'script', 'content', 'input', 'prompt', 'utterance', 'words'];

const Request = z
  .object({
    message_id: z.string().min(1).max(400),
    voice_id: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/),
    params: z
      .record(
        z.string().regex(/^[a-z_]{1,40}$/),
        z.union([z.string().regex(/^[a-z0-9_:]{1,40}$/), z.number()]),
      )
      .optional(),
  })
  .strict();

/** spec 9.4: EMERGENCY | CRISIS | MED_BOUNDARY (and any other non-OK). */
const NOT_SAFETY = new Set(['ok', 'none']);

const CONSENTED_CLONES = new Set(['self', 'self_clone', 'loved_one', 'loved_one_clone']);
const LICENSED = new Set(['gokula']);

/** Unique per call, so every request gets its own audit entry. */
const stamp = () => `${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;

interface Trail {
  messageId: string;
  source: string;
  voiceId: string | null;
  voiceKind: VoiceKind | 'unknown';
}

export async function speakMessageFor(
  uid: string,
  raw: unknown,
  deps: GatewayDeps,
): Promise<GatewayResult> {
  const db = deps.db ?? getFirestore;
  const trail: Trail = { messageId: 'invalid', source: 'invalid', voiceId: null, voiceKind: 'unknown' };

  const refuse = async (reason: RefusalReason): Promise<never> => {
    // Fail closed: if the refusal can't be logged, it is still a refusal.
    await deps.log
      .append(`tts_refused_${uid}_${stamp()}`, {
        actor: uid,
        action: 'voice.tts_refused',
        target: trail.voiceId ? `users/${uid}/voices/${trail.voiceId}` : `users/${uid}/voices`,
        details: {
          reason,
          message_id: trail.messageId,
          source: trail.source,
          voice_kind: trail.voiceKind,
        },
      })
      .catch(() => undefined);
    throw new GatewayRefusal(reason);
  };

  // 1. Never free text.
  if (raw !== null && typeof raw === 'object') {
    const keys = Object.keys(raw);
    if (keys.some((k) => FREE_TEXT_KEYS.includes(k.toLowerCase()))) {
      return refuse('free_text_refused');
    }
  }

  // 2. Safety first, with no reads and no vendor (FR-VOC-07). Checked
  // before the rest of the request, so nothing else can block it.
  const rawId = (raw as { message_id?: unknown } | null)?.message_id;
  if (typeof rawId === 'string' && parseMessageId(rawId)?.source === 'safety') {
    trail.messageId = rawId;
    trail.source = 'safety';
    return neutral(uid, trail, deps.log);
  }

  const parsedReq = Request.safeParse(raw);
  if (!parsedReq.success) return refuse('bad_request');
  const req = parsedReq.data;
  trail.voiceId = req.voice_id;

  const parsed = parseMessageId(req.message_id);
  if (!parsed || parsed.source === 'safety') return refuse('unknown_message');
  trail.messageId = parsed.id;
  trail.source = parsed.source;

  // 3. The approved, versioned text, looked up here.
  const found = await lookup(uid, parsed, deps.scripts, db);
  if (!found.ok) return refuse(found.reason);
  const script = found.script;
  if (script.safetyCategory && !NOT_SAFETY.has(script.safetyCategory.toLowerCase())) {
    return neutral(uid, trail, deps.log);
  }

  // 4. The voice, and for a cloned or licensed voice its consent.
  const voiceSnap = await db().doc(`users/${uid}/voices/${req.voice_id}`).get();
  if (!voiceSnap.exists) return refuse('unknown_voice');
  const voice = voiceSnap.data()!;
  const kindName = String(voice.kind ?? '');
  const kind: VoiceKind | null =
    kindName === 'library' ? 'library'
    : CONSENTED_CLONES.has(kindName) ? 'cloned'
    : LICENSED.has(kindName) ? 'licensed'
    : null;
  if (!kind) return refuse('unsupported_voice_kind');
  trail.voiceKind = kind;
  if (voice.status !== 'active') return refuse('voice_inactive');

  if (kind === 'cloned') {
    if (!deps.config.clonedVoicesEnabled) return refuse('cloned_voices_off');
    const consentId = voice.consent_id;
    if (typeof consentId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(consentId)) {
      return refuse('consent_missing');
    }
    const consentSnap = await db().doc(`voice_consents/${consentId}`).get();
    if (!consentSnap.exists) return refuse('consent_missing');
    const c = consentSnap.data()!;
    if (c.account_uid !== uid) return refuse('consent_wrong_account');
    if (c.status !== 'active' || (c.revoked_at ?? null) !== null || (c.revoked_by ?? null) !== null) {
      return refuse('consent_revoked');
    }
    // Spec 11 example: the clone may speak only inside this one account.
    if (c.permitted_use !== `coaching_messages_in_account_${uid}_only`) {
      return refuse('consent_wrong_account');
    }
  }
  if (kind === 'licensed' && !deps.config.gokulaVoiceEnabled) {
    // FR-VOC-04: off until the license and legal sign-off (T-VOC-08).
    return refuse('gokula_voice_off');
  }

  // 5. A cloned or licensed voice never says words the person typed.
  if (kind !== 'library' && script.containsUserText !== false) {
    return refuse('user_text_not_allowed');
  }

  // 6. The final text: approved words plus closed-set values only.
  const params: Params = req.params ?? {};
  let text: string;
  if (parsed.source === 'orchestrator') {
    if (Object.keys(params).length > 0) return refuse('bad_params');
    text = script.text;
  } else {
    const r = render(script.text, params, deps.scripts);
    if (!r.ok) return refuse(r.reason);
    text = r.text;
  }

  // 7. Synthesis. No audio leaves without its audit entry.
  let audio: { audio: Buffer; mime: string };
  try {
    audio = await deps.tts.synthesize({
      vendorVoiceId: String(voice.vendor_voice_id ?? ''),
      text,
      speed: typeof voice.speed === 'number' ? voice.speed : 1,
    });
  } catch {
    return refuse('tts_unavailable');
  }
  await deps.log.append(`tts_synth_${uid}_${stamp()}`, {
    actor: uid,
    action: 'voice.tts_synthesized',
    target: `users/${uid}/voices/${req.voice_id}`,
    details: {
      message_id: parsed.id,
      source: parsed.source,
      voice_kind: kind,
      chars: text.length,
    },
  });
  return {
    status: 'ok',
    message_id: parsed.id,
    voice_kind: kind,
    ai_voice_label: kind !== 'library',
    mime: audio.mime,
    audio_base64: audio.audio.toString('base64'),
  };
}

/** FR-VOC-07. The audit entry is best effort: logging must never hold up
 * a safety message. */
async function neutral(uid: string, trail: Trail, log: AuditLog): Promise<GatewayResult> {
  await log
    .append(`tts_neutral_${uid}_${stamp()}`, {
      actor: uid,
      action: 'voice.tts_routed_neutral',
      target: trail.voiceId ? `users/${uid}/voices/${trail.voiceId}` : `users/${uid}/voices`,
      details: { message_id: trail.messageId, source: trail.source },
    })
    .catch(() => undefined);
  return { status: 'neutral_device', message_id: trail.messageId };
}

async function lookup(
  uid: string,
  parsed: Exclude<ParsedMessageId, { source: 'safety' }>,
  scripts: ScriptBundle,
  db: () => Firestore,
): Promise<Lookup> {
  if (parsed.source === 'moment' || parsed.source === 'routine') {
    return lookupBundled(scripts, parsed);
  }
  if (parsed.source === 'lesson') {
    const snap = await db().doc(`content_items/${parsed.itemId}`).get();
    if (!snap.exists) return { ok: false, reason: 'unknown_message' };
    const item = snap.data()!;
    if (typeof item.version !== 'number') return { ok: false, reason: 'unknown_message' };
    if (parsed.version !== item.version) {
      return { ok: false, reason: parsed.version < item.version ? 'retired_message' : 'unknown_message' };
    }
    if (item.review_status !== 'approved') return { ok: false, reason: 'not_approved' };
    let text: unknown;
    if (parsed.part === 'habit') {
      text = (item.microhabit as { title?: unknown } | undefined)?.title;
    } else {
      const cards = Array.isArray(item.cards) ? item.cards : [];
      text = cards[Number(parsed.part.slice(1)) - 1];
    }
    if (typeof text !== 'string' || !text) return { ok: false, reason: 'unknown_message' };
    // Lessons are fixed approved copy; any {placeholder} in them is refused
    // by render() (fail closed).
    return { ok: true, script: { text, containsUserText: false } };
  }
  // Orchestrator: written only by the server after the safety post-check
  // (firestore.rules: users/{uid}/messages is read-only for clients).
  const snap = await db().doc(`users/${uid}/messages/${parsed.id}`).get();
  if (!snap.exists) return { ok: false, reason: 'unknown_message' };
  const m = snap.data()!;
  const safety = (m.safety ?? {}) as { status?: unknown; category?: unknown };
  if (typeof safety.category === 'string' && !NOT_SAFETY.has(safety.category.toLowerCase())) {
    return { ok: true, script: { text: '', safetyCategory: safety.category } };
  }
  if (safety.status !== 'approved') return { ok: false, reason: 'not_approved' };
  if (typeof m.text !== 'string' || !m.text) return { ok: false, reason: 'unknown_message' };
  return {
    ok: true,
    script: {
      text: m.text,
      containsUserText: m.contains_user_text === false ? false : true,
    },
  };
}
