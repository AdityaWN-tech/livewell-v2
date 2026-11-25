import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Admin / CMS staff: who may call admin endpoints (spec 10.2, 16.2,
 * T-PRT-02, D-92). HUMAN REVIEW REQUIRED (security).
 *
 * Roles are Firebase Auth custom claims, set only with the Admin SDK by the
 * owner's script (`scripts/set-staff-claims.mjs`), never by a client:
 *   { "staff_roles": ["content_editor", "clinical_reviewer", ...] }
 *
 * MFA (spec 16.2 "Admin portal with MFA"). The method is still an owner
 * question (TOTP preferred; needs Identity Platform, which needs Blaze;
 * D-90, D-92). Until it is decided, this gate is conservative: a staff
 * token is accepted only if
 *   (a) the sign-in used a second factor (`firebase.sign_in_second_factor`
 *       is set by Identity Platform MFA), or
 *   (b) the owner set a time-limited waiver claim on that account,
 *       `staff_mfa_waiver_until` (seconds since epoch, at most 30 days
 *       ahead of the token's issue time), which is shown in the audit log.
 * No role without MFA or a live waiver: the call is refused. Nothing is
 * skipped silently.
 */

export const STAFF_ROLES = [
  'content_editor',
  'clinical_reviewer',
  'safety_reviewer',
  'admin',
] as const;

export type StaffRole = (typeof STAFF_ROLES)[number];

/** Longest waiver the gate honours, counted from the token's issue time. */
export const MAX_MFA_WAIVER_SECONDS = 30 * 24 * 60 * 60;

export interface Staff {
  uid: string;
  roles: ReadonlySet<StaffRole>;
  /** How MFA was satisfied, for the audit log. */
  mfa: 'second_factor' | 'waiver';
}

/** The parts of a decoded ID token the gate reads. */
export interface TokenLike {
  uid?: string;
  iat?: number;
  staff_roles?: unknown;
  staff_mfa_waiver_until?: unknown;
  firebase?: { sign_in_second_factor?: unknown };
  [key: string]: unknown;
}

export function rolesOf(token: TokenLike): Set<StaffRole> {
  const raw = token.staff_roles;
  if (!Array.isArray(raw)) return new Set();
  return new Set(
    raw.filter((r): r is StaffRole => (STAFF_ROLES as readonly unknown[]).includes(r)),
  );
}

export function mfaOf(token: TokenLike, nowSeconds: number): Staff['mfa'] | null {
  const second = token.firebase?.sign_in_second_factor;
  if (typeof second === 'string' && second.length > 0) return 'second_factor';
  const until = token.staff_mfa_waiver_until;
  const iat = typeof token.iat === 'number' ? token.iat : 0;
  if (
    typeof until === 'number' &&
    Number.isFinite(until) &&
    until > nowSeconds &&
    until - iat <= MAX_MFA_WAIVER_SECONDS
  ) {
    return 'waiver';
  }
  return null;
}

/**
 * The caller as staff with at least one of [allowed], or an HttpsError:
 * unauthenticated (no token), permission-denied (no staff role, no MFA, or
 * not one of the allowed roles). The message never says which check failed
 * beyond what the signed-in person needs to fix it.
 */
export function requireStaff(
  auth: { uid: string; token: TokenLike } | undefined,
  allowed: readonly StaffRole[],
  nowSeconds = Math.floor(Date.now() / 1000),
): Staff {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const roles = rolesOf(auth.token);
  if (roles.size === 0) {
    throw new HttpsError('permission-denied', 'This account has no staff role.', {
      reason: 'not_staff',
    });
  }
  const mfa = mfaOf(auth.token, nowSeconds);
  if (!mfa) {
    throw new HttpsError('permission-denied', 'Two-step sign-in is required for staff.', {
      reason: 'mfa_required',
    });
  }
  if (!allowed.some((r) => roles.has(r))) {
    throw new HttpsError('permission-denied', 'Your role cannot do this.', {
      reason: 'role',
    });
  }
  return { uid: auth.uid, roles, mfa };
}

export function hasAny(staff: Staff, roles: readonly StaffRole[]): boolean {
  return roles.some((r) => staff.roles.has(r));
}
