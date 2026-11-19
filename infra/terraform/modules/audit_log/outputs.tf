output "audit_writer_email" {
  description = "Set as AUDIT_WRITER_SA on the Core API functions."
  value       = google_service_account.audit_writer.email
}

output "audit_bucket" {
  value = google_logging_project_bucket_config.audit.id
}
