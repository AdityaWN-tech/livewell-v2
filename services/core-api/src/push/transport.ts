import { getMessaging, type TokenMessage } from 'firebase-admin/messaging';

/**
 * The one place a push leaves our servers: Firebase Cloud Messaging (FCM
 * delivers to APNs for iPhones). Everything else in src/push is our own
 * logic; tests replace only this interface (test/push.test.ts
 * `FakeTransport`), so no test ever talks to FCM.
 */
export interface PushTransport {
  /** One result per message, in order. */
  send(messages: TokenMessage[]): Promise<SendResult[]>;
}

export type SendResult = { ok: true } | { ok: false; code: string };

/** FCM says this token will never work again: the device is removed. */
export const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export class FcmTransport implements PushTransport {
  async send(messages: TokenMessage[]): Promise<SendResult[]> {
    if (messages.length === 0) return [];
    const res = await getMessaging().sendEach(messages);
    return res.responses.map((r) =>
      r.success ? { ok: true } : { ok: false, code: r.error?.code ?? 'unknown' },
    );
  }
}
