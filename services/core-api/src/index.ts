import { initializeApp } from 'firebase-admin/app';

import { makeDeletions } from './account/deletions.js';
import { makeOnConsentCreated } from './consents/on-consent-created.js';
import { makeOnPushRequest } from './push/on-push-request.js';

initializeApp();

/** Audit entry for every consent grant or revocation (T-FND-05). */
export const onConsentCreated = makeOnConsentCreated();

/**
 * "Delete my avatar", "Delete my voice", "Delete my account" (FR-SET-02/03,
 * T-ONB-03f), each with an audit entry.
 */
export const { deleteAvatar, deleteVoice, deleteAccount } = makeDeletions();

/**
 * Server push (T-TCH-01, D-77): each push_outbox request goes through
 * sendPush (notifications consent, category toggle, quiet hours, daily cap
 * of 4, fixed generic words, invalid tokens removed).
 */
export const onPushRequest = makeOnPushRequest();
