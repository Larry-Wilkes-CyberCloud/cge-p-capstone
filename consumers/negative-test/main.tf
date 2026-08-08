terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = "cge-p-capstone"
  region  = "us-central1"
}

module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "cge-p-capstone"
  project_label      = "cgep-lab"
  environment        = "prod"
  retention_days     = 30   # FAILS: prod requires >= 365
  bucket_name_suffix = "should-never-exist"
}