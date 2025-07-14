variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "gracehandai-v1"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "screenshot_bucket_name" {
  description = "Name for the GCS bucket for screenshots"
  type        = string
  default     = "gracehand-screenshots-prod"
}

variable "backend_image" {
  description = "Docker image for backend"
  type        = string
  default     = "us-central1-docker.pkg.dev/gracehandai-v1/gracehand-repo/gracehand-backend:latest"
}

variable "frontend_image" {
  description = "Docker image for frontend"
  type        = string
  default     = "us-central1-docker.pkg.dev/gracehandai-v1/gracehand-repo/gracehand-frontend:latest"
}