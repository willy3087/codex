# Variables for Codex Gateway Terraform configuration

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "elaihub-prod"
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (prod, staging, dev)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "Environment must be one of: prod, staging, dev"
  }
}

variable "service_account_email" {
  description = "Email of the Cloud Run service account"
  type        = string
  default     = "467992722695-compute@developer.gserviceaccount.com"
}

variable "artifacts_bucket_lifecycle_age" {
  description = "Number of days to keep artifacts before deletion"
  type        = number
  default     = 30
}

variable "enable_firestore" {
  description = "Enable Firestore database creation"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Cloud Monitoring metrics"
  type        = bool
  default     = true
}
