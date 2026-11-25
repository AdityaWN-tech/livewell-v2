import { HttpsError } from 'firebase-functions/v2/https';
import { describe, expect, it } from 'vitest';

import {
  errorCode,
  monitored,
  safeLog,
  scrubFields,
  type LogSink,
} from '../src/observability/log.js';

// T-FND-10 / D-80 (NFR-10): logs carry only event names, ids, counts and
// durations. Pure tests; they also run inside the emulator `npm test`.

const PHI = [
  'I feel awful today and skipped my pills',
  'mood 2/5',
  'glucose 182 mg/dL',
  'BP 150/95',
  'jane@example.com',
];

function capture() {
  const lines: string[] = [];
  const sink: LogSink = (severity, payload) =>
    lines.push(`${severity} ${JSON.stringify(payload)}`);
  return { lines, sink };
}

describe('scrubFields', () => {
  it('drops unknown fields and free text, counting them', () => {
    const out = scrubFields({
      fn: 'deleteAvatar',
      note: PHI[0],
      mood: 2,
      code: PHI[1],
      duration_ms: 12.6,
      count: Number.NaN,
    });
    expect(out).toEqual({ fn: 'deleteAvatar', duration_ms: 13, dropped_fields: 4 });
  });

  it('never lets a PHI-like value through any allowed field', () => {
    for (const text of PHI) {
      const out = scrubFields({ fn: text, code: text, outcome: text, count: text });
      expect(JSON.stringify(out)).not.toContain(text);
    }
  });
});

describe('errorCode', () => {
  it('is a code or class name, never the message', () => {
    expect(errorCode(new HttpsError('unauthenticated', PHI[0]))).toBe('unauthenticated');
    expect(errorCode({ code: 'auth/user-not-found', message: PHI[4] })).toBe(
      'auth/user-not-found',
    );
    expect(errorCode(new TypeError(PHI[2]))).toBe('TypeError');
    expect(errorCode({ code: PHI[3] })).toBe('unknown');
    expect(errorCode(PHI[0])).toBe('unknown');
  });
});

describe('monitored', () => {
  it('logs fn.ok with a duration', async () => {
    const { lines, sink } = capture();
    const f = monitored('deleteVoice', async (n: number) => n + 1, { sink });
    expect(await f(1)).toBe(2);
    expect(lines).toHaveLength(1);
    expect(lines[0]).toMatch(/^info \{"event":"fn.ok","fn":"deleteVoice","duration_ms":\d+\}$/);
  });

  it('logs fn.error with the code only and hides raw errors from callers', async () => {
    const { lines, sink } = capture();
    const f = monitored(
      'deleteAccount',
      async () => {
        throw new Error(PHI[0]);
      },
      { callable: true, sink },
    );
    const err = await f().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(HttpsError);
    expect((err as HttpsError).code).toBe('internal');
    expect((err as HttpsError).message).not.toContain(PHI[0]);
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain('"event":"fn.error"');
    expect(lines[0]).toContain('"code":"Error"');
    expect(lines[0]).toMatch(/^error /);
    for (const text of PHI) expect(lines.join('\n')).not.toContain(text);
  });

  it('passes HttpsErrors through and logs 4xx as warn', async () => {
    const { lines, sink } = capture();
    const f = monitored(
      'deleteAvatar',
      async () => {
        throw new HttpsError('unauthenticated', 'Sign in first.');
      },
      { callable: true, sink },
    );
    const err = await f().catch((e: unknown) => e);
    expect((err as HttpsError).code).toBe('unauthenticated');
    expect(lines[0]).toMatch(/^warn .*"code":"unauthenticated"/);
  });

  it('rethrows the original error for triggers', async () => {
    const { sink } = capture();
    const boom = new RangeError('x');
    const f = monitored(
      'onConsentCreated',
      async () => {
        throw boom;
      },
      { sink },
    );
    await expect(f()).rejects.toBe(boom);
  });
});

describe('safeLog', () => {
  it('only takes a fixed event name and allow-listed fields', () => {
    const { lines, sink } = capture();
    safeLog('info', 'fn.ok', { fn: 'deleteAvatar', count: 3 }, sink);
    expect(lines).toEqual(['info {"event":"fn.ok","fn":"deleteAvatar","count":3}']);
  });
});
