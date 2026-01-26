terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.16.0"
    }
  }
}

provider "google" {
  credentials = file(var.gcp_credentials)
  project     = var.project
  region      = "us-central1"
}

resource "google_storage_bucket" "demo-bucket" {
  name          = "sixth-hash-485519-d9-demo-bucket"
  location      = var.location
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 3
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

resource "google_bigquery_dataset" "demo-dataset" {
  dataset_id = "demo_dataset"
  project    = var.project
  location   = var.location
}
