provider "google" {
  region  = "${var.region}"
  version = "~> 1.18"
}

terraform {
  backend "gcs" {
    prefix = "vault-configure"
  }
}
