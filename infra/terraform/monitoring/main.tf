resource "google_project_service" "monitoring" {
  for_each           = toset(["monitoring.googleapis.com", "logging.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Live Well alerts (email)"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
  depends_on = [google_project_service.monitoring]
}

# Counts the Core API's own error lines (services/core-api/src/observability
# /log.ts). Those lines hold only the event, function name, error code and
# duration: no PHI or free text (NFR-10).
resource "google_logging_metric" "core_api_fn_errors" {
  name   = "core_api_fn_errors"
  filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.event=\"fn.error\" AND severity>=ERROR"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "fn"
      value_type  = "STRING"
      description = "Function name"
    }
  }
  label_extractors = {
    fn = "EXTRACT(jsonPayload.fn)"
  }
  depends_on = [google_project_service.monitoring]
}

resource "google_monitoring_alert_policy" "core_api_fn_errors" {
  display_name = "Core API: function errors"
  combiner     = "OR"
  conditions {
    display_name = "fn.error lines > ${var.fn_error_threshold} in 5 min"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.core_api_fn_errors.name}\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.fn_error_threshold
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["metric.label.fn"]
      }
      trigger {
        count = 1
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "A Core API function is failing. Logs: Logs Explorer, jsonPayload.event=\"fn.error\" (fields: fn, code, duration_ms). Runbook: docs/setup/monitoring.md."
    mime_type = "text/markdown"
  }
}

# Any server error from a Cloud Functions 2nd gen / Cloud Run service,
# including ones that never reach our logger (cold-start crash, timeout).
resource "google_monitoring_alert_policy" "http_5xx" {
  display_name = "Cloud Run / Functions: 5xx responses"
  combiner     = "OR"
  conditions {
    display_name = "5xx > ${var.http_5xx_threshold} in 5 min"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND metric.label.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.http_5xx_threshold
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }
      trigger {
        count = 1
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "Server errors on a Cloud Run service (NFR-04: Core API 99.5% monthly uptime). Runbook: docs/setup/monitoring.md."
    mime_type = "text/markdown"
  }
  depends_on = [google_project_service.monitoring]
}

resource "google_monitoring_alert_policy" "latency_p95" {
  display_name = "Cloud Run / Functions: slow responses (p95)"
  combiner     = "OR"
  conditions {
    display_name = "p95 latency > ${var.latency_p95_ms} ms for 10 min"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_latencies\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_p95_ms
      duration        = "600s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = ["resource.label.service_name"]
      }
      trigger {
        count = 1
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content   = "A service has been slow for 10 minutes. Check cold starts (min instances) and Firestore latency. Runbook: docs/setup/monitoring.md."
    mime_type = "text/markdown"
  }
  depends_on = [google_project_service.monitoring]
}

# Errors and latency at a glance (spec 15.4). Cost per DAU, safety events
# and agent traces get their tiles when those services exist (D-80).
resource "google_monitoring_dashboard" "core_api" {
  dashboard_json = jsonencode({
    displayName = "Live Well: Core API"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos = 0, yPos = 0, width = 6, height = 4
          widget = {
            title = "Requests by response class"
            xyChart = {
              dataSets = [{
                plotType = "STACKED_BAR"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_SUM"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code_class"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos = 6, yPos = 0, width = 6, height = 4
          widget = {
            title = "p95 latency by service (ms)"
            xyChart = {
              dataSets = [{
                plotType = "LINE"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"run.googleapis.com/request_latencies\" AND resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_PERCENTILE_95"
                      crossSeriesReducer = "REDUCE_MAX"
                      groupByFields      = ["resource.label.service_name"]
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos = 0, yPos = 4, width = 12, height = 4
          widget = {
            title = "Core API fn.error by function"
            xyChart = {
              dataSets = [{
                plotType = "STACKED_BAR"
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.core_api_fn_errors.name}\" AND resource.type=\"cloud_run_revision\""
                    aggregation = {
                      alignmentPeriod    = "300s"
                      perSeriesAligner   = "ALIGN_SUM"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.fn"]
                    }
                  }
                }
              }]
            }
          }
        },
      ]
    }
  })
  depends_on = [google_project_service.monitoring]
}

output "notification_channel" {
  value = google_monitoring_notification_channel.email.id
}
