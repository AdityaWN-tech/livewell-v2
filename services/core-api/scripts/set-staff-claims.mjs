#!/usr/bin/env node
// Sets an Admin / CMS staff member's roles (and, until MFA is decided, a
// short MFA waiver) as Firebase Auth custom claims (T-PRT-02, D-92).
// Owner-only: runs with the owner's own Google credentials (Application
// Default Credentials, `gcloud auth application-default login`), never from
// the app or CI. Every change is written to the audit log.
//
//   node scripts/set-staff-claims.mjs --project my-livewell --email a@b.org \
//     --roles content_editor,clinical_reviewer [--mfa-waiver-days 7]
//   node scripts/set-staff-claims.mjs --project my-livewell --email a@b.org --roles none
//
// Roles: content_editor, clinical_reviewer, safety_reviewer, admin.
// The person must sign out and in again for new claims to apply.
import { parseArgs } from 'node:util';

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const ROLES = ['content_editor', 'clinical_reviewer', 'safety_reviewer', 'admin'];
const MAX_WAIVER_DAYS = 30; // must match MAX_MFA_WAIVER_SECONDS in src/admin/staff.ts

const { values } = parseArgs({
  options: {
    project: { type: 'string' },
    email: { type: 'string' },
    roles: { type: 'string' },
    'mfa-waiver-days': { type: 'string' },
  },
});
if (!values.project || !values.email || !values.roles) {
  console.error('Usage: --project <id> --email <staff email> --roles <a,b|none> [--mfa-waiver-days N]');
  process.exit(2);
}
const roles = values.roles === 'none' ? [] : values.roles.split(',').map((r) => r.trim());
const unknown = roles.filter((r) => !ROLES.includes(r));
if (unknown.length) {
  console.error(`Unknown roles: ${unknown.join(', ')}. Allowed: ${ROLES.join(', ')}`);
  process.exit(2);
}
const days = values['mfa-waiver-days'] ? Number(values['mfa-waiver-days']) : 0;
if (!Number.isInteger(days) || days < 0 || days > MAX_WAIVER_DAYS) {
  console.error(`--mfa-waiver-days must be a whole number from 0 to ${MAX_WAIVER_DAYS}`);
  process.exit(2);
}

initializeApp({ projectId: values.project });
const auth = getAuth();
const user = await auth.getUserByEmail(values.email);
const claims = { ...(user.customClaims ?? {}) };
delete claims.staff_roles;
delete claims.staff_mfa_waiver_until;
if (roles.length) claims.staff_roles = roles;
if (roles.length && days > 0) {
  claims.staff_mfa_waiver_until = Math.floor(Date.now() / 1000) + days * 24 * 3600;
}
await auth.setCustomUserClaims(user.uid, claims);
// Revoke sessions so old tokens with old roles stop working within an hour.
await auth.revokeRefreshTokens(user.uid);

await getFirestore()
  .collection('audit_log')
  .doc(`staff_roles_${user.uid}_${Date.now().toString(36)}`)
  .create({
    actor: 'owner_script',
    action: 'admin.role_changed',
    target: `staff/${user.uid}`,
    details: { roles: roles.join(',') || 'none', mfa_waiver_days: days },
    ip_hash: null,
    timestamp: Timestamp.now(),
  });
console.log(`Set roles [${roles.join(', ') || 'none'}] for ${user.uid}; MFA waiver days: ${days}.`);
