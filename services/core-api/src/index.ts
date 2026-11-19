import { initializeApp } from 'firebase-admin/app';

import { makeDeletions } from './account/deletions.js';
import { makeOnConsentCreated } from './consents/on-consent-created.js';
import { makePortalOfferCallables } from './portal/portal-offers.js';

initializeApp();

/** Audit entry for every consent grant or revocation (T-FND-05). */
export const onConsentCreated = makeOnConsentCreated();

/**
 * "Delete my avatar", "Delete my voice", "Delete my account" (FR-SET-02/03,
 * T-ONB-03f), each with an audit entry.
 */
export const { deleteAvatar, deleteVoice, deleteAccount } = makeDeletions();

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
