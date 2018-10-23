provider "google" {
  region  = "${var.region}"
  version = "1.18"
}

terraform {
  required_version = "0.11.8"

  backend "gcs" {
    prefix = "vault-license-services"
  }
}
