import { initializeApp } from 'firebase-admin/app';

import { makeOnConsentCreated } from './consents/on-consent-created.js';

initializeApp();

/** Audit entry for every consent grant or revocation (T-FND-05). */
export const onConsentCreated = makeOnConsentCreated();
