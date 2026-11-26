import { HttpsError, onCall, type FunctionsErrorCode } from 'firebase-functions/v2/https';

import { FirestoreAuditLog, type AuditLog } from '../audit/audit-log.js';
import {
  configFromEnv,
  GatewayRefusal,
  speakMessageFor,
  type GatewayConfig,
  type RefusalReason,
} from './gateway.js';
import type { ScriptBundle } from './scripts.js';
import { bundledScripts } from './scripts.generated.js';
import { UnconfiguredTts, type TtsAdapter } from './tts-adapter.js';

const CODES: Record<RefusalReason, FunctionsErrorCode> = {
  free_text_refused: 'invalid-argument',
  bad_request: 'invalid-argument',
  bad_params: 'invalid-argument',
  unknown_message: 'not-found',
  unknown_voice: 'not-found',
  retired_message: 'failed-precondition',
  not_approved: 'failed-precondition',
  unknown_placeholder: 'failed-precondition',
  user_text_not_allowed: 'permission-denied',
  unsupported_voice_kind: 'permission-denied',
  voice_inactive: 'permission-denied',
  cloned_voices_off: 'permission-denied',
  gokula_voice_off: 'permission-denied',
  consent_missing: 'permission-denied',
  consent_revoked: 'permission-denied',
  consent_wrong_account: 'permission-denied',
  tts_unavailable: 'unavailable',
};

/**
 * `speakMessage` callable: the closed-script TTS gateway (T-VOC-07; spec
 * 12.1 `GET /v1/tts/{message_id}/stream`, as a Firebase callable until the
 * vendor's streaming is chosen in T-VOC-01). The uid always comes from the
 * auth token. Body: `{message_id, voice_id, params?}`; text is refused.
 */
export function makeSpeakMessage(
  deps: {
    scripts?: ScriptBundle;
    tts?: TtsAdapter;
    log?: AuditLog;
    config?: GatewayConfig;
  } = {},
) {
  const scripts = deps.scripts ?? bundledScripts;
  const tts = deps.tts ?? new UnconfiguredTts();
  const log = deps.log ?? new FirestoreAuditLog();
  return onCall(async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
    try {
      return await speakMessageFor(req.auth.uid, req.data, {
        scripts,
        tts,
        log,
        config: deps.config ?? configFromEnv(),
      });
    } catch (e) {
      if (e instanceof GatewayRefusal) {
        throw new HttpsError(CODES[e.reason], e.reason, { reason: e.reason });
      }
      throw e;
    }
  });
}
