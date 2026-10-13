# Legal texts (versioned)

Source of truth for the texts users accept (FR-ONB-02). File name = `<consent key>-<version>.md`, matching `ConsentTexts.versionOf()` in the app.
**All files here are DRAFTS written from the spec's commitments, not legal advice.** Counsel replaces them (T-CMP-01), with US and India (DPDP) variants (D-03); bump the version when wording changes.
The app bundles copies in `apps/mobile/assets/legal/`; `test/onboarding/legal_texts_test.dart` fails if they drift.
