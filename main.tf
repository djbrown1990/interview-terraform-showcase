terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "cloud_run" {
  project = var.project_id
  service = "run.googleapis.com"
}

resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "vertex_ai" {
  project = var.project_id
  service = "aiplatform.googleapis.com"
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"
}

resource "google_project_service" "iam_credentials" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"
}

# Create workforce pool
resource "google_iam_workforce_pool" "main" {
  workforce_pool_id = "gracehand-workforce-pool"
  parent            = "organizations/${var.organization_id}"
  display_name      = "GraceHand Workforce Pool"
  description       = "Workforce pool for GraceHand.AI deployment and management"
  session_duration  = "3600s"
  location          = "global"
  
  depends_on = [google_project_service.iam]
}

# Create workforce pool provider for Google identity
resource "google_iam_workforce_pool_provider" "google_provider" {
  workforce_pool_id          = google_iam_workforce_pool.main.workforce_pool_id
  workforce_pool_provider_id = "google-provider"
  parent                     = google_iam_workforce_pool.main.name
  display_name               = "Google Identity Provider"
  description                = "Google identity provider for workforce authentication"
  
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "google.display_name"  = "assertion.name"
    "google.groups"        = "assertion.groups"
    "attribute.email"      = "assertion.email"
  }
  
  oidc {
    issuer_uri        = "https://accounts.google.com"
    client_id         = var.google_client_id
    client_secret     = var.google_client_secret
    web_sso_config {
      response_type             = "CODE"
      assertion_claims_behavior = "MERGE_USER_INFO_OVER_ID_TOKEN_CLAIMS"
    }
  }
}

# Use existing service account
data "google_service_account" "cloud_run_sa" {
  account_id = "gracehand-run-sa"
  project    = var.project_id
}

# Grant workforce pool users permission to impersonate service account
resource "google_service_account_iam_member" "workforce_pool_sa_impersonation" {
  service_account_id = data.google_service_account.cloud_run_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "principalSet://iam.googleapis.com/${google_iam_workforce_pool.main.name}/attribute.email/${var.allowed_user_email}"
}

# Grant workforce pool users necessary permissions
resource "google_project_iam_member" "workforce_pool_cloud_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "principalSet://iam.googleapis.com/${google_iam_workforce_pool.main.name}/attribute.email/${var.allowed_user_email}"
}

resource "google_project_iam_member" "workforce_pool_artifact_registry_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "principalSet://iam.googleapis.com/${google_iam_workforce_pool.main.name}/attribute.email/${var.allowed_user_email}"
}

resource "google_project_iam_member" "workforce_pool_vertex_ai_admin" {
  project = var.project_id
  role    = "roles/aiplatform.admin"
  member  = "principalSet://iam.googleapis.com/${google_iam_workforce_pool.main.name}/attribute.email/${var.allowed_user_email}"
}

# Cloud Run Service
resource "google_cloud_run_service" "backend" {
  name     = "gracehand-backend-staging"
  location = var.region

  template {
    spec {
      service_account_name = data.google_service_account.cloud_run_sa.email
      containers {
        image = var.backend_image
        
        env {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        }
        
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }
    }
  }

  depends_on = [google_project_service.cloud_run]
}

# Cloud Storage Bucket
resource "google_storage_bucket" "screenshots" {
  name     = var.screenshot_bucket_name
  location = var.region
  
  uniform_bucket_level_access = true
}

# IAM Bindings
resource "google_cloud_run_service_iam_member" "public" {
  service  = google_cloud_run_service.backend.name
  location = google_cloud_run_service.backend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
} 