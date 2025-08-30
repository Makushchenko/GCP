# Configure the Google Cloud provider
provider "google" {
  # The GCP project to use
  project = var.GOOGLE_PROJECT
  # The GCP region to deploy resources in
  region = var.GOOGLE_REGION

  default_labels = {
    environment = "demo"
    owner       = "makushchenko"
    project     = var.GOOGLE_PROJECT
  }
}
