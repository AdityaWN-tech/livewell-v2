/**
 * Every action the audit log accepts (T-FND-09). An action not listed here
 * is refused by the writer, so a new audited event is a reviewed change to
 * this file. Spec sources: consents (FR-ONB-02/03, 16.3), deletions and
 * export (FR-SET-02/03), voice and avatar consent (FR-VOC, FR-AVT, 16.3),
 * safety events (16.x), admin actions (spec 10.2 Admin/CMS).
 *
 * "Reserved" actions have no writer on main yet; their tasks call
 * `AuditLog.append` with these names instead of inventing new ones.
 */
export const AUDIT_ACTIONS = [
  // Consents (T-FND-05; revoke handling: PR #88, D-76).
  'consent.granted',
  'consent.revoked',
  'consent.revoke_handled',
  'consent.revoke_followup',
  // Deletions (T-ONB-03f, FR-SET-02/03).
  'avatar.deleted',
  'voice.deleted',
  'account.deleted',
  // Data export (T-CMP-03, PR #95, D-82).
  'data_export.requested',
  'data_export.ready',
  'data_export.failed',
  'data_export.link_issued',
  // Data migration of the prototype's users arrays (T-FND-07, D-83).
  'migration.plan',
  'migration.copy',
  'migration.verify',
  'migration.cleanup',
  'migration.rollback',
  // Portal catalog in Admin (T-PRT-02, D-92): one per offer revision.
  'admin.portal_offer_created',
  'admin.portal_offer_updated',
  'admin.portal_offer_submitted',
  'admin.portal_offer_withdrawn',
  'admin.portal_offer_approved',
  'admin.portal_offer_rejected',
  'admin.portal_offer_published',
  'admin.portal_offer_unpublished',
  'admin.portal_offer_archived',
  'admin.portal_offer_restored',
  // Closed-script voice gateway (T-VOC-07, D-88): ids and counts only.
  'voice.tts_synthesized',
  'voice.tts_refused',
  'voice.tts_routed_neutral',
  // Reserved: voice and avatar consent (T-VOC-*, T-AVT-*).
  'voice_consent.granted',
  'voice_consent.revoked',
  'voice_clone.deleted',
  'avatar_vendor.deleted',
  // Reserved: safety events (T-SAF-*). Ids and categories only, never text.
  'safety_event.created',
  'safety_event.reviewed',
  // Reserved: admin and CMS (T-ADM-*).
  'admin.content_approved',
  'admin.content_rejected',
  'admin.role_changed',
  'admin.user_data_accessed',
] as const;

export type AuditAction = (typeof AUDIT_ACTIONS)[number];
