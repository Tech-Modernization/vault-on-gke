provider "google" {
  region  = "${var.region}"
  version = "~> 1.18"
}

provider "kubernetes" {
  # We don't want to load ~/.kube/config by default, will be getting the credentials later
  # https://www.terraform.io/docs/providers/kubernetes/index.html#load_config_file
  load_config_file = false

  host     = "${google_container_cluster.vault.endpoint}"
  username = "${google_container_cluster.vault.master_auth.0.username}"
  password = "${google_container_cluster.vault.master_auth.0.password}"

  client_certificate     = "${base64decode(google_container_cluster.vault.master_auth.0.client_certificate)}"
  client_key             = "${base64decode(google_container_cluster.vault.master_auth.0.client_key)}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.vault.master_auth.0.cluster_ca_certificate)}"
}

terraform {
  backend "gcs" {
    prefix = "vault"
  }
}
