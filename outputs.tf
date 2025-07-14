# Workforce pool outputs
output "workforce_pool_name" {
  description = "The name of the workforce pool"
  value       = google_iam_workforce_pool.main.name
}

output "workforce_pool_id" {
  description = "The ID of the workforce pool"
  value       = google_iam_workforce_pool.main.workforce_pool_id
}

output "google_provider_name" {
  description = "The name of the Google identity provider"
  value       = google_iam_workforce_pool_provider.google_provider.name
}

output "workforce_pool_sign_in_url" {
  description = "The sign-in URL for the workforce pool"
  value       = "https://auth.cloud.google.com/workforce-pools/${google_iam_workforce_pool.main.workforce_pool_id}/providers/google-provider"
}

# Cloud Run outputs
output "backend_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_service.backend.status[0].url
}

# Storage outputs
output "screenshot_bucket" {
  description = "Name of the screenshot bucket"
  value       = google_storage_bucket.screenshots.name
}