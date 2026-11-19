import { initializeApp } from 'firebase-admin/app';

import { makeDeletions } from './account/deletions.js';
import { makeOnConsentCreated } from './consents/on-consent-created.js';
import { makeSpeakMessage } from './voice/speak-message.js';

initializeApp();

/** Audit entry for every consent grant or revocation (T-FND-05). */
export const onConsentCreated = makeOnConsentCreated();

/**
 * "Delete my avatar", "Delete my voice", "Delete my account" (FR-SET-02/03,
 * T-ONB-03f), each with an audit entry.
 */
export const { deleteAvatar, deleteVoice, deleteAccount } = makeDeletions();

/**
 * The closed-script voice gateway (T-VOC-07, FR-VOC-05/07): every synthesis
 * in a coach voice goes through here, by approved message_id only.
 */
export const speakMessage = makeSpeakMessage();
