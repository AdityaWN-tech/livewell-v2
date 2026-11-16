variable "project_id" {
  description = "Firebase / GCP project id (dev: my-livewell; staging and prod once created)."
  type        = string
}

variable "alert_email" {
  description = "Where alerts go (a team inbox, not a personal address). Set in a *.tfvars file that is not committed."
  type        = string
}

variable "fn_error_threshold" {
  description = "Core API fn.error log lines (severity ERROR) in 5 minutes that raise an alert."
  type        = number
  default     = 3
}

variable "http_5xx_threshold" {
  description = "5xx responses across Cloud Run services (Cloud Functions 2nd gen) in 5 minutes that raise an alert."
  type        = number
  default     = 5
}

variable "latency_p95_ms" {
  description = "p95 request latency per service, in ms, that raises an alert when held for 10 minutes."
  type        = number
  default     = 2000
}
