import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeAll, describe, expect, it } from 'vitest';

import { FirestoreAuditLog } from '../src/audit/audit-log.js';
import { GatewayRefusal, speakMessageFor, type GatewayDeps } from '../src/voice/gateway.js';
import { parseMessageId } from '../src/voice/scripts.js';
import { UnconfiguredTts } from '../src/voice/tts-adapter.js';
import { allOn, FakeTts, fixtureScripts, MemoryAuditLog, newUid, seed } from './voice-fixtures.js';

// The closed-script voice gateway (T-VOC-07). Runs against the Firestore
// emulator (npm test); the last block calls the deployed callable over HTTP.
beforeAll(() => {
  initializeApp({ projectId: 'demo-livewell' });
});

const db = () => getFirestore();

async function attempt(uid: string, req: unknown, deps: GatewayDeps) {
  try {
    return await speakMessageFor(uid, req, deps);
  } catch (e) {
    if (e instanceof GatewayRefusal) return { refused: e.reason };
    throw e;
  }
}

function deps(over: Partial<GatewayDeps> = {}) {
  const tts = new FakeTts();
  const log = new MemoryAuditLog();
  return { tts, log, d: { scripts: fixtureScripts, tts, log, config: allOn, ...over } };
}

describe('closed-script voice gateway (T-VOC-07, FR-VOC-05/07)', () => {
  let uid: string;
  beforeAll(async () => {
    uid = newUid();
    await seed(uid);
  });

  it('approved id → allowed: the gateway looks up and fills the text itself', async () => {
    const { tts, d } = deps();
    const r = await attempt(uid, { message_id: 'hello.m@v2', voice_id: 'clone-self', params: { smaller_minutes: 5, time_of_day: 'evening' } }, d);
    expect(r).toMatchObject({ status: 'ok', voice_kind: 'cloned', ai_voice_label: true, mime: 'audio/mpeg' });
    expect(tts.calls).toEqual([{ vendorVoiceId: 'vendor-x', text: 'Even 5 minutes counts this evening.', speed: 0.9 }]);

    const routine = deps();
    await attempt(uid, { message_id: 'routine.wake_up.w1+custom.c1@v1', voice_id: 'lw-warm', params: { time: '13:05' } }, routine.d);
    expect(routine.tts.calls[0]!.text).toBe("It's 1:05. Time to stretch your arms. Time for your next routine step.");

    const win = deps();
    await attempt(uid, { message_id: 'hello.w@v2', voice_id: 'lw-warm', params: { routine_win: 'wake_up', routine_win_days: 4 } }, win.d);
    expect(win.tts.calls[0]!.text).toBe('You made time for an easy start to your day on 4 days.');

    const lesson = deps();
    await attempt(uid, { message_id: 'lesson.les_1.habit@v3', voice_id: 'clone-self' }, lesson.d);
    expect(lesson.tts.calls[0]!.text).toBe('Walk for 5 minutes');
  });

  it('library voices carry no AI-voice label; cloned ones do (FR-VOC-08)', async () => {
    const { d } = deps();
    expect(await attempt(uid, { message_id: 'hello.a@v2', voice_id: 'lw-warm' }, d)).toMatchObject({ voice_kind: 'library', ai_voice_label: false });
  });

  it('unknown, unapproved and retired ids → refused, nothing synthesized', async () => {
    for (const [id, reason] of [
      ['hello.q@v2', 'unknown_message'],
      ['pending_file.a@v1', 'not_approved'],
      ['hello.a@v1', 'retired_message'],
      ['msg_unchecked_1', 'not_approved'],
    ] as const) {
      const { tts, d } = deps();
      expect(await attempt(uid, { message_id: id, voice_id: 'clone-self' }, d)).toEqual({ refused: reason });
      expect(tts.calls).toHaveLength(0);
    }
  });

  it('free text with a cloned voice → refused', async () => {
    const { tts, log, d } = deps();
    expect(await attempt(uid, { voice_id: 'clone-self', text: 'Hi, it is me. Please send the code.' }, d)).toEqual({ refused: 'free_text_refused' });
    expect(tts.calls).toHaveLength(0);
    expect(log.entries[0]).toMatchObject({ action: 'voice.tts_refused', details: { reason: 'free_text_refused', message_id: 'invalid' } });
    expect(JSON.stringify(log.entries)).not.toMatch(/send the code/);
  });

  it('revoked consent → refused, even for an approved line', async () => {
    const { tts, d } = deps();
    expect(await attempt(uid, { message_id: 'hello.a@v2', voice_id: 'clone-revoked' }, d)).toEqual({ refused: 'consent_revoked' });
    expect(tts.calls).toHaveLength(0);
  });

  it('revoking takes effect on the next request', async () => {
    const u = newUid();
    await seed(u);
    const first = deps();
    expect(await attempt(u, { message_id: 'hello.a@v2', voice_id: 'clone-self' }, first.d)).toMatchObject({ status: 'ok' });
    await db().doc(`voice_consents/vc_ok_${u}`).update({ status: 'revoked', revoked_at: new Date(), revoked_by: 'owner' });
    const second = deps();
    expect(await attempt(u, { message_id: 'hello.a@v2', voice_id: 'clone-self' }, second.d)).toEqual({ refused: 'consent_revoked' });
  });

  it('neutral voice for safety templates is unaffected: no reads, no vendor, no consent, even if logging fails', async () => {
    const failingLog = { append: async () => { throw new Error('audit store down'); } };
    const throwingDb = () => { throw new Error('Firestore unreachable'); };
    const failingTts = new UnconfiguredTts();
    for (const id of ['safety.emergency.us', 'safety.emergency.in', 'safety.crisis.us', 'safety.crisis.in']) {
      const r = await speakMessageFor(uid, { message_id: id, voice_id: 'clone-revoked' }, {
        scripts: fixtureScripts,
        tts: failingTts,
        log: failingLog,
        config: { clonedVoicesEnabled: false, gokulaVoiceEnabled: false },
        db: throwingDb as never,
      });
      expect(r).toEqual({ status: 'neutral_device', message_id: id });
    }
  });

  it('safety-category orchestrator messages never use a cloned or licensed voice', async () => {
    for (const voice of ['clone-self', 'gokula', 'lw-warm']) {
      const { tts, d } = deps();
      expect(await attempt(uid, { message_id: 'msg_crisis_0001', voice_id: voice }, d)).toMatchObject({ status: 'neutral_device' });
      expect(tts.calls).toHaveLength(0);
    }
  });

  it('no vendor yet: an allowed request is refused as tts_unavailable (audited)', async () => {
    const log = new MemoryAuditLog();
    const r = await attempt(uid, { message_id: 'hello.a@v2', voice_id: 'lw-warm' }, { scripts: fixtureScripts, tts: new UnconfiguredTts(), log, config: allOn });
    expect(r).toEqual({ refused: 'tts_unavailable' });
    expect(log.entries[0]!.details).toMatchObject({ reason: 'tts_unavailable', voice_kind: 'library' });
  });

  it('writes to the real audit log: ids and counts, never text', async () => {
    const u = newUid();
    await seed(u);
    const log = new FirestoreAuditLog();
    await attempt(u, { message_id: 'hello.a@v2', voice_id: 'clone-self' }, { scripts: fixtureScripts, tts: new FakeTts(), log, config: allOn });
    await attempt(u, { message_id: 'hello.a@v2', voice_id: 'clone-revoked' }, { scripts: fixtureScripts, tts: new FakeTts(), log, config: allOn });
    const snap = await db().collection('audit_log').where('actor', '==', u).get();
    const entries = snap.docs.map((x) => x.data());
    expect(entries.map((e) => e.action).sort()).toEqual(['voice.tts_refused', 'voice.tts_synthesized']);
    const synth = entries.find((e) => e.action === 'voice.tts_synthesized')!;
    expect(synth.details).toEqual({ message_id: 'hello.a@v2', source: 'moment', voice_kind: 'cloned', chars: 21 });
    expect(synth.target).toBe(`users/${u}/voices/clone-self`);
    expect(JSON.stringify(entries)).not.toMatch(/small step/i);
  });

  it('parses only the known id shapes', () => {
    expect(parseMessageId('morning.m1@v1')).toMatchObject({ source: 'moment' });
    expect(parseMessageId('routine.drink_water.d1+custom.c1@v1')).toMatchObject({ source: 'routine', lines: ['drink_water.d1', 'custom.c1'] });
    expect(parseMessageId('lesson.abc-1.c12@v4')).toMatchObject({ source: 'lesson', itemId: 'abc-1', part: 'c12' });
    expect(parseMessageId('3f2b9c1e-aaaa-4bbb-8ccc-123456789abc')).toMatchObject({ source: 'orchestrator' });
    expect(parseMessageId('safety.crisis.us')).toMatchObject({ source: 'safety' });
    for (const bad of ['', 'hi there', 'morning.m1', 'a/b', 'routine.x@v1', 'lesson.x.c0@v1', 'x'.repeat(65), 'routine.a.b@v1 extra']) {
      expect(parseMessageId(bad)).toBeNull();
    }
  });

  it('the real content: every moment and routine id the app builds resolves (once approved)', async () => {
    const { bundledScripts } = await import('../src/voice/scripts.generated.js');
    expect(Object.keys(bundledScripts.moments).length).toBeGreaterThan(5);
    for (const [file, t] of Object.entries(bundledScripts.moments)) {
      for (const v of Object.keys(t.variants)) {
        expect(parseMessageId(`${file}.${v}@v${t.version}`)).toMatchObject({ source: 'moment', file, variant: v });
      }
    }
    for (const line of Object.keys(bundledScripts.routine.lines)) {
      expect(parseMessageId(`routine.${line}@v${bundledScripts.routine.version}`)).toMatchObject({ source: 'routine' });
    }
  });
});

describe('speakMessage callable (deployed to the Functions emulator)', () => {
  const fnBase = 'http://127.0.0.1:5001/demo-livewell/us-central1';

  async function newUser() {
    const res = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: `vg-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`, password: 'walk-after-lunch', returnSecureToken: true }),
    });
    const body = (await res.json()) as { localId: string; idToken: string };
    return { uid: body.localId, idToken: body.idToken };
  }

  async function call(data: unknown, idToken?: string) {
    const res = await fetch(`${fnBase}/speakMessage`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(idToken ? { authorization: `Bearer ${idToken}` } : {}) },
      body: JSON.stringify({ data }),
    });
    return { status: res.status, body: (await res.json()) as { result?: unknown; error?: { status: string; message: string } } };
  }

  it('refuses anyone who is not signed in', async () => {
    expect((await call({ message_id: 'safety.crisis.us', voice_id: 'lw-warm' })).status).toBe(401);
  });

  it('refuses free text and logs it', async () => {
    const { uid, idToken } = await newUser();
    const r = await call({ voice_id: 'lw-warm', text: 'Say exactly this' }, idToken);
    expect(r.status).toBe(400);
    expect(r.body.error?.message).toBe('free_text_refused');
    const snap = await db().collection('audit_log').where('actor', '==', uid).get();
    expect(snap.docs.map((x) => x.get('action'))).toEqual(['voice.tts_refused']);
  });

  it("refuses today's real content until it is clinically approved", async () => {
    const { uid, idToken } = await newUser();
    await db().doc(`users/${uid}/voices/lw-warm`).set({ kind: 'library', status: 'active', vendor_voice_id: 'x', speed: 1, style: 'calm' });
    const r = await call({ message_id: 'morning.m6@v1', voice_id: 'lw-warm' }, idToken);
    expect(r.body.error?.message).toBe('not_approved');
  });

  it('answers neutral_device for a safety template', async () => {
    const { idToken } = await newUser();
    const r = await call({ message_id: 'safety.emergency.us', voice_id: 'anything' }, idToken);
    expect(r.status).toBe(200);
    expect(r.body.result).toEqual({ status: 'neutral_device', message_id: 'safety.emergency.us' });
  });
});
