import { initializeApp } from 'firebase-admin/app';

import { makeDataExport } from './account/data-export.js';
import { makeDeletions } from './account/deletions.js';
import { makeOnConsentCreated } from './consents/on-consent-created.js';

initializeApp();

/** Audit entry for every consent grant or revocation (T-FND-05). */
export const onConsentCreated = makeOnConsentCreated();

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
