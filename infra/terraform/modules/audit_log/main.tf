# Audit log, append-only (T-FND-09, D-85, spec 10.2 and 16.x).
# HUMAN SECURITY REVIEW REQUIRED. Not applied yet (Spark plan, D-17).
#
# - audit-writer: a service account whose ONLY role is roles/logging.logWriter
#   (logging.logEntries.create). It can add audit entries; it can't read,
#   change or delete them. No keys are created: the Core API's runtime
#   account impersonates it for 5-minute tokens.
# - A Cloud Logging bucket with 6-year retention, locked: entries can't be
#   edited or deleted by anyone, and the bucket can't be deleted or its
#   retention shortened while entries are inside it.
# - A sink that routes the `livewell-audit` log into that bucket.
# Readers (auditors) get a log view on the bucket, separately.

locals {
  audit_log_name = "livewell-audit" # same as AUDIT_LOG_NAME in services/core-api/src/audit/audit-mirror.ts
}

resource "google_service_account" "audit_writer" {
  project      = var.project_id
  account_id   = "audit-writer"
  display_name = "Audit log writer (write-only)"
  description  = "Writes audit entries only (roles/logging.logWriter). Cannot read, change or delete them. T-FND-09."
}

# The one and only role of audit-writer.
resource "google_project_iam_member" "audit_writer_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.audit_writer.email}"
}

# The Core API may act as audit-writer (short-lived tokens), nothing more.
resource "google_service_account_iam_member" "core_api_impersonates_audit_writer" {
  service_account_id = google_service_account.audit_writer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.core_api_runtime_sa}"
}

resource "google_logging_project_bucket_config" "audit" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "livewell-audit"
  retention_days = var.retention_days
  locked         = var.lock_bucket
  description    = "Append-only audit log (T-FND-09). Retention-locked; no health content (spec 16.3)."
}

resource "google_logging_project_sink" "audit" {
  project                = var.project_id
  name                   = "livewell-audit-to-locked-bucket"
  destination            = "logging.googleapis.com/${google_logging_project_bucket_config.audit.id}"
  filter                 = "logName=\"projects/${var.project_id}/logs/${local.audit_log_name}\""
  unique_writer_identity = true
}

# Read access for auditors only, through a view on the audit bucket.
resource "google_logging_log_view" "auditors" {
  name        = "auditors"
  bucket      = google_logging_project_bucket_config.audit.id
  description = "Read-only view of the audit log for named auditors."
  filter      = "LOG_ID(\"${local.audit_log_name}\")"
}

resource "google_logging_log_view_iam_member" "auditors" {
  for_each = toset(var.auditor_members)
  parent   = google_logging_log_view.auditors.parent
  location = google_logging_log_view.auditors.location
  bucket   = google_logging_log_view.auditors.bucket
  name     = google_logging_log_view.auditors.name
  role     = "roles/logging.viewAccessor"
  member   = each.value
}
