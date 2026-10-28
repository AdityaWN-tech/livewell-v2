/// Where people ask for a copy of their data (FR-SET-02) until the export
/// function exists. Set per build:
/// `--dart-define=LW_DATA_REQUEST_EMAIL=privacy@example.com`. Empty (the
/// default): Profile shows no export row at all (Step 4d, D-56).
/// needs-product: the client's privacy or support address.
const dataRequestEmail = String.fromEnvironment('LW_DATA_REQUEST_EMAIL');
