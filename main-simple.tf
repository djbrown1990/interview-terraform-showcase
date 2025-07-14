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

resource "google_project_service" "cloudbuild" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = "gracehand-repo"
  description   = "GraceHand.AI container repository"
  format        = "DOCKER"
  
  depends_on = [google_project_service.artifact_registry]
}

# Create service account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  account_id   = "gracehand-run-sa"
  display_name = "GraceHand Cloud Run Service Account"
}

# Grant permissions to service account
resource "google_project_iam_member" "cloud_run_sa_storage" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_sa_vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Storage Bucket
resource "google_storage_bucket" "screenshots" {
  name          = var.screenshot_bucket_name
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
}

# Cloud Run Service for Backend
resource "google_cloud_run_service" "backend" {
  name     = "gracehand-backend"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      containers {
        image = var.backend_image
        
        ports {
          container_port = 8080
        }
        
        env {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
        
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
        
        env {
          name  = "SCREENSHOT_BUCKET_NAME"
          value = google_storage_bucket.screenshots.name
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.cloud_run]
}

# Cloud Run Service for Frontend
resource "google_cloud_run_service" "frontend" {
  name     = "gracehand-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = var.frontend_image
        
        ports {
          container_port = 3000
        }
        
        env {
          name  = "REACT_APP_API_URL"
          value = google_cloud_run_service.backend.status[0].url
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.cloud_run]
}

# Allow public access to services
resource "google_cloud_run_service_iam_member" "backend_public" {
  service  = google_cloud_run_service.backend.name
  location = google_cloud_run_service.backend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_service_iam_member" "frontend_public" {
  service  = google_cloud_run_service.frontend.name
  location = google_cloud_run_service.frontend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}