import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { getBytes, ref, uploadString } from 'firebase/storage';
import { afterAll, beforeAll, describe, it } from 'vitest';

import { ALICE, BOB, PROJECT_ID } from './helpers';

// Cloud Storage is server-only (D-82): export zips and coach frames are
// reached only through short-lived signed URLs, never by the app directly.
let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: readFileSync(fileURLToPath(new URL('../storage.rules', import.meta.url)), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadString(ref(ctx.storage(), `exports/${ALICE}/j1.zip`), 'zip');
  });
});
afterAll(async () => {
  await env.cleanup();
});

describe('storage.rules (T-CMP-03)', () => {
  it('nobody reads an export zip directly, not even its owner', async () => {
    for (const ctx of [env.authenticatedContext(ALICE), env.authenticatedContext(BOB), env.unauthenticatedContext()]) {
      await assertFails(getBytes(ref(ctx.storage(), `exports/${ALICE}/j1.zip`)));
    }
  });
  it('the app can write nothing, anywhere', async () => {
    const alice = env.authenticatedContext(ALICE).storage();
    await assertFails(uploadString(ref(alice, `exports/${ALICE}/mine.zip`), 'x'));
    await assertFails(uploadString(ref(alice, `avatars/${ALICE}/v1/frame.webp`), 'x'));
    await assertFails(uploadString(ref(alice, 'anything/else.txt'), 'x'));
  });
});
