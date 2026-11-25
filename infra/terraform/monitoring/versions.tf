# Monitoring and alerting as code (T-FND-10, D-80; spec 10.2 Observability,
# NFR-04 availability, 15.4 dashboards). One apply per environment
# (dev / staging / prod), see docs/setup/monitoring.md.
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  # State is local until the shared GCS state bucket exists (T-FND-02
  # follow-up); never commit *.tfstate (see .gitignore).
}

provider "google" {
  project = var.project_id
}
