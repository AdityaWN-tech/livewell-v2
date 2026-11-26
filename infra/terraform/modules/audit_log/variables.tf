variable "project_id" {
  description = "GCP / Firebase project (dev, staging or prod)."
  type        = string
}

variable "core_api_runtime_sa" {
  description = "Email of the service account the Core API functions run as. It may only mint short-lived tokens for audit-writer (no keys)."
  type        = string
}

variable "retention_days" {
  description = "Audit log retention: 6 years (spec retention table, 'Audit log: 6 years (append-only)')."
  type        = number
  default     = 2190
}

variable "lock_bucket" {
  description = "Lock the bucket's retention. IRREVERSIBLE: a locked bucket can't be deleted or have its retention reduced. Keep true for staging and prod; dev may set false."
  type        = bool
  default     = true
}

variable "auditor_members" {
  description = "Principals that may READ the audit bucket (e.g. group:security@...). Never the Core API or audit-writer."
  type        = list(string)
  default     = []
}
