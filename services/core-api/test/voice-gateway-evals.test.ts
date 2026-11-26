import { readFileSync } from 'node:fs';

import { initializeApp } from 'firebase-admin/app';
import { beforeAll, describe, expect, it } from 'vitest';

import { GatewayRefusal, speakMessageFor, type GatewayConfig } from '../src/voice/gateway.js';
import { allOn, FakeTts, fixtureScripts, MemoryAuditLog, newUid, seed } from './voice-fixtures.js';

// T-VOC-07 evaluation and pen-test set (evals/voice-gateway-cases.json).
// Every case runs through the real gateway against the Firestore emulator.

interface Case {
  name: string;
  critical: boolean;
  voice: string;
  request: Record<string, unknown>;
  config?: Partial<GatewayConfig>;
  expect: string;
}

const cases = (
  JSON.parse(readFileSync(new URL('../evals/voice-gateway-cases.json', import.meta.url), 'utf8')) as {
    cases: Case[];
  }
).cases;

let uid: string;
beforeAll(async () => {
  initializeApp({ projectId: 'demo-livewell' });
  uid = newUid();
  await seed(uid);
});

describe('voice gateway evaluation set (T-VOC-07)', () => {
  it('has the cases the task asks for', () => {
    const expects = new Set(cases.map((c) => c.expect));
    for (const e of ['ok', 'neutral_device', 'free_text_refused', 'unknown_message', 'not_approved', 'retired_message', 'consent_revoked']) {
      expect(expects).toContain(e);
    }
    expect(cases.filter((c) => c.critical).length).toBeGreaterThanOrEqual(40);
  });

  for (const c of cases) {
    it(`${c.critical ? '[critical] ' : ''}${c.name} → ${c.expect}`, async () => {
      const tts = new FakeTts();
      const log = new MemoryAuditLog();
      const deps = { scripts: fixtureScripts, tts, log, config: { ...allOn, ...c.config } };
      let outcome: string;
      try {
        const r = await speakMessageFor(uid, { voice_id: c.voice, ...c.request }, deps);
        outcome = r.status;
      } catch (e) {
        if (!(e instanceof GatewayRefusal)) throw e;
        outcome = e.reason;
      }
      expect(outcome).toBe(c.expect);

      // Only an allowed request reaches the vendor; nothing else is spoken.
      expect(tts.calls).toHaveLength(c.expect === 'ok' ? 1 : 0);

      // Exactly one audit entry, with ids and counts only: none of the
      // request's or the script's words (spec 16.3).
      expect(log.entries).toHaveLength(1);
      const entry = log.entries[0]!;
      expect(entry.action).toBe(
        c.expect === 'ok' ? 'voice.tts_synthesized'
        : c.expect === 'neutral_device' ? 'voice.tts_routed_neutral'
        : 'voice.tts_refused',
      );
      const logged = JSON.stringify(entry);
      for (const v of Object.values(c.request)) {
        if (typeof v === 'string' && /\s/.test(v)) expect(logged).not.toContain(v);
      }
      for (const call of tts.calls) expect(logged).not.toContain(call.text);
      expect(logged).not.toMatch(/Priya|money|walk|stretch|small step/i);
    });
  }
});
