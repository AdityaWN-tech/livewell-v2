import { initializeApp } from 'firebase-admin/app';

import { makeDataExport } from './account/data-export.js';
import { makeDeletions } from './account/deletions.js';
import { makeOnConsentCreated } from './consents/on-consent-created.js';
import { makeRevokeSweep } from './consents/revoke-sweep.js';
import { makePortalOfferCallables } from './portal/portal-offers.js';
import { makeOnPushRequest } from './push/on-push-request.js';

initializeApp();

/**
 * Audit entry for every consent grant or revocation (T-FND-05), and the
 * spec 16.3 handling when a consent is revoked (FR-ONB-03, D-76).
 */
export const onConsentCreated = makeOnConsentCreated();

/** Hourly retry of revoke handling, well inside the 24 h limit (D-76). */
export const consentRevokeSweep = makeRevokeSweep();

/**
 * "Delete my avatar", "Delete my voice", "Delete my account" (FR-SET-02/03,
 * T-ONB-03f), each with an audit entry.
 */
export const { deleteAvatar, deleteVoice, deleteAccount } = makeDeletions();

/**
 * "Download my data" (FR-SET-02, T-CMP-03, D-82): request, build (trigger)
 * and a short-lived download link.
 */
export const { requestDataExport, onDataExportRequested, getDataExportLink } =
  makeDataExport();

/**
 * Portal catalog for the Admin / CMS (T-PRT-02, D-92): staff-only,
 * role-checked, MFA-gated and audited.
 */
export const {
  adminListPortalOffers,
  adminCreatePortalOffer,
  adminUpdatePortalOffer,
  adminTransitionPortalOffer,
} = makePortalOfferCallables();

/**
 * Server push (T-TCH-01, D-77): each push_outbox request goes through
 * sendPush (notifications consent, category toggle, quiet hours, daily cap
 * of 4, fixed generic words, invalid tokens removed).
 */
export const onPushRequest = makeOnPushRequest();
