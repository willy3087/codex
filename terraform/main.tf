# Terraform configuration for Codex Gateway infrastructure on GCP
# This creates all the necessary resources for running the gateway

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Optional: Use GCS backend for state management
  # backend "gcs" {
  #   bucket = "elaihub-prod-terraform-state"
  #   prefix = "codex-gateway"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ==============================================================================
# Cloud Storage Bucket for Artifacts
# ==============================================================================

resource "google_storage_bucket" "artifacts" {
  name          = "${var.project_id}-codex-artifacts"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30  # Delete artifacts older than 30 days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    environment = var.environment
    service     = "codex-gateway"
    managed_by  = "terraform"
  }
}

# Grant Cloud Run service account access to the bucket
resource "google_storage_bucket_iam_member" "artifacts_access" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account_email}"
}

# ==============================================================================
# Firestore Database (for API Keys and Sessions)
# ==============================================================================

resource "google_firestore_database" "main" {
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  # Concurrency mode
  concurrency_mode = "OPTIMISTIC"

  # App Engine integration
  app_engine_integration_mode = "DISABLED"
}

# ==============================================================================
# Secret Manager Secrets
# ==============================================================================

# Gateway API Key
resource "google_secret_manager_secret" "gateway_api_key" {
  secret_id = "gateway-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    service     = "codex-gateway"
  }
}

# Anthropic API Key
resource "google_secret_manager_secret" "anthropic_api_key" {
  secret_id = "anthropic-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    service     = "codex-gateway"
  }
}

# OpenAI API Key (optional)
resource "google_secret_manager_secret" "openai_api_key" {
  secret_id = "openai-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    service     = "codex-gateway"
  }
}

# Pipedrive API Token (optional)
resource "google_secret_manager_secret" "pipedrive_api_token" {
  secret_id = "pipedrive-api-token"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    service     = "codex-gateway"
  }
}

# ==============================================================================
# IAM Permissions for Secret Access
# ==============================================================================

# Grant Cloud Run service account access to secrets
resource "google_secret_manager_secret_iam_member" "gateway_api_key_access" {
  secret_id = google_secret_manager_secret.gateway_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "anthropic_api_key_access" {
  secret_id = google_secret_manager_secret.anthropic_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "openai_api_key_access" {
  secret_id = google_secret_manager_secret.openai_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "pipedrive_api_token_access" {
  secret_id = google_secret_manager_secret.pipedrive_api_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}

# ==============================================================================
# Cloud Monitoring - Log-based Metrics
# ==============================================================================

# Metric for API requests
resource "google_logging_metric" "api_requests" {
  name   = "codex_gateway_api_requests"
  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"wrapper\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "endpoint"
      value_type  = "STRING"
      description = "API endpoint"
    }

    labels {
      key         = "status"
      value_type  = "STRING"
      description = "HTTP status code"
    }
  }

  label_extractors = {
    "endpoint" = "EXTRACT(httpRequest.requestUrl)"
    "status"   = "EXTRACT(httpRequest.status)"
  }
}

# Metric for errors
resource "google_logging_metric" "api_errors" {
  name   = "codex_gateway_api_errors"
  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"wrapper\" AND severity>=ERROR"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

# ==============================================================================
# Outputs
# ==============================================================================

output "artifacts_bucket_name" {
  description = "Name of the GCS bucket for artifacts"
  value       = google_storage_bucket.artifacts.name
}

output "artifacts_bucket_url" {
  description = "URL of the GCS bucket for artifacts"
  value       = google_storage_bucket.artifacts.url
}

output "firestore_database_name" {
  description = "Name of the Firestore database"
  value       = google_firestore_database.main.name
}

output "secret_ids" {
  description = "Secret Manager secret IDs"
  value = {
    gateway_api_key      = google_secret_manager_secret.gateway_api_key.secret_id
    anthropic_api_key    = google_secret_manager_secret.anthropic_api_key.secret_id
    openai_api_key       = google_secret_manager_secret.openai_api_key.secret_id
    pipedrive_api_token  = google_secret_manager_secret.pipedrive_api_token.secret_id
  }
}
