import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { Timestamp, doc, setDoc, serverTimestamp } from 'firebase/firestore';

export const PROJECT_ID = 'demo-livewell';
export const ALICE = 'alice';
export const BOB = 'bob';

export async function makeEnv(): Promise<RulesTestEnvironment> {
  const rulesPath = fileURLToPath(new URL('../firestore.rules', import.meta.url));
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(rulesPath, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
}

/** created_at / updated_at / schema_version on every document (spec 11). */
export function meta() {
  const now = Timestamp.now();
  return { created_at: now, updated_at: now, schema_version: 1 };
}

/** Meta where created_at must equal request.time (consents). */
export function serverMeta() {
  return {
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    schema_version: 1,
  };
}

export function profile(overrides: Record<string, unknown> = {}) {
  return {
    display_name: 'Priya',
    tz: 'America/New_York',
    locale: 'en_US',
    region: 'US',
    age_confirmed: true,
    onboarding_step: 'why',
    ...meta(),
    ...overrides,
  };
}

/** Seeds documents as the server would (rules bypassed). */
export async function seed(
  env: RulesTestEnvironment,
  docs: Record<string, Record<string, unknown>>,
) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(db, path), data);
    }
  });
}

/** Alice with a profile that passed the 18+ gate. */
export async function seedAdult(env: RulesTestEnvironment, uid = ALICE) {
  await seed(env, { [`users/${uid}`]: profile() });
}
