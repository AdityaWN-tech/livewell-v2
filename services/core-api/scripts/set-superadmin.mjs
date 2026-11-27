#!/usr/bin/env node
// Makes (or unmakes) a Superadmin for the staff portals (D-112).
// Owner-only: runs on the owner's laptop with their own Google credentials
// (`gcloud auth application-default login`), never from the app or CI.
// Free plan: no Cloud Functions needed. Only verified @whitenoiseacademy.com
// accounts can be Superadmins; the Firestore rules check this again.
//
//   node scripts/set-superadmin.mjs --project my-livewell --email you@whitenoiseacademy.com
//   node scripts/set-superadmin.mjs --project my-livewell --email you@whitenoiseacademy.com --remove
//
// The person signs in to the Admin web app with Google first (so the account
// exists), then signs out and in again after this script for it to apply.
import { parseArgs } from 'node:util';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const DOMAIN = '@whitenoiseacademy.com';

const { values } = parseArgs({
  options: {
    project: { type: 'string' },
    email: { type: 'string' },
    remove: { type: 'boolean', default: false },
  },
});
if (!values.project || !values.email) {
  console.error('Usage: --project <id> --email <name@whitenoiseacademy.com> [--remove]');
  process.exit(2);
}
const email = values.email.trim().toLowerCase();
if (!email.endsWith(DOMAIN)) {
  console.error(`Only ${DOMAIN} accounts can be Superadmins.`);
  process.exit(2);
}

initializeApp({ projectId: values.project });
const auth = getAuth();
let user;
try {
  user = await auth.getUserByEmail(email);
} catch {
  console.error(`No account for ${email} yet. Sign in to the Admin web app with Google first.`);
  process.exit(1);
}
if (!values.remove && !user.emailVerified) {
  console.error(`${email} is not verified. Use "Continue with Google" to sign in.`);
  process.exit(1);
}

const claims = { ...(user.customClaims ?? {}) };
if (values.remove) delete claims.superadmin;
else claims.superadmin = true;
await auth.setCustomUserClaims(user.uid, claims);
// Old sessions end: the new claim applies at the next sign-in.
await auth.revokeRefreshTokens(user.uid);

await getFirestore()
  .collection('staff_audit')
  .add({
    actor: 'owner_script',
    action: values.remove ? 'staff.removed' : 'staff.approved',
    target: `superadmin/${user.uid}`,
    at: FieldValue.serverTimestamp(),
  });

console.log(`${email} is ${values.remove ? 'no longer' : 'now'} a Superadmin. Sign out and in again.`);
