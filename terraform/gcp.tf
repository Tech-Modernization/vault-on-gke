resource "random_id" "random" {
  prefix      = "vault-"
  byte_length = "8"
}

data "google_organization" "org" {
  domain = "${var.org}"
}

# Create the project
resource "google_project" "vault" {
  name            = "${random_id.random.hex}"
  project_id      = "${random_id.random.hex}"
  org_id          = "${data.google_organization.org.id}"
  billing_account = "${var.billing_account}"
}

# Create the vault service account
resource "google_service_account" "vault-server" {
  account_id   = "vault-server"
  display_name = "Vault Server"
  project      = "${google_project.vault.project_id}"
}

# Create a service account key
resource "google_service_account_key" "vault" {
  service_account_id = "${google_service_account.vault-server.name}"
}

# Add the service account to the project
resource "google_project_iam_member" "service-account" {
  count   = "${length(var.service_account_iam_roles)}"
  project = "${google_project.vault.project_id}"
  role    = "${element(var.service_account_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.vault-server.email}"
}

# Enable required services on the project
resource "google_project_service" "service" {
  count   = "${length(var.project_services)}"
  project = "${google_project.vault.project_id}"
  service = "${element(var.project_services, count.index)}"

  # Do not disable the service on destroy. On destroy, we are going to
  # destroy the project, but we need the APIs available to destroy the
  # underlying resources.
  disable_on_destroy = false
}

# Create the storage bucket
resource "google_storage_bucket" "vault" {
  name          = "${google_project.vault.project_id}-vault-storage"
  project       = "${google_project.vault.project_id}"
  force_destroy = true
  storage_class = "MULTI_REGIONAL"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      num_newer_versions = 3
    }
  }

  depends_on = ["google_project_service.service"]
}

# Grant service account access to the storage bucket
resource "google_storage_bucket_iam_member" "vault-server" {
  count  = "${length(var.storage_bucket_roles)}"
  bucket = "${google_storage_bucket.vault.name}"
  role   = "${element(var.storage_bucket_roles, count.index)}"
  member = "serviceAccount:${google_service_account.vault-server.email}"
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault" {
  name     = "vault"
  location = "${var.region}"
  project  = "${google_project.vault.project_id}"

  depends_on = ["google_project_service.service"]
}

# Create the crypto key for encrypting init keys
resource "google_kms_crypto_key" "vault-init" {
  name            = "vault-init"
  key_ring        = "${google_kms_key_ring.vault.id}"
  rotation_period = "604800s"
}

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "vault-init" {
  count         = "${length(var.kms_crypto_key_roles)}"
  crypto_key_id = "${google_kms_crypto_key.vault-init.id}"
  role          = "${element(var.kms_crypto_key_roles, count.index)}"
  member        = "serviceAccount:${google_service_account.vault-server.email}"
}

resource "google_compute_network" "shared_vpc" {
  name                    = "${random_id.random.hex}-vpc"
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
  project                 = "${google_project.vault.project_id}"

  depends_on = ["google_project_service.service"]
}

resource "google_compute_subnetwork" "service_subnet" {
  name          = "${random_id.random.hex}-subnet"
  project       = "${google_project.vault.project_id}"
  ip_cidr_range = "10.100.0.0/24"
  network       = "${google_compute_network.shared_vpc.self_link}"

  # access PaaS without external IP
  private_ip_google_access = true
}

# Allow inbound traffic on 8200
resource "google_compute_firewall" "vault-inbound" {
  name    = "${google_project.vault.project_id}-vault-inbound"
  project = "${google_project.vault.project_id}"
  network = "${google_compute_network.shared_vpc.self_link}"

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["8200"]
  }

  source_ranges = [
    "0.0.0.0/0"
  ]
}

# Get latest cluster version
data "google_container_engine_versions" "versions" {
  zone    = "${var.zone}"
  project = "${google_project.vault.project_id}"
}

# Create the GKE cluster
resource "google_container_cluster" "vault" {
  name    = "vault"
  project = "${google_project.vault.project_id}"
  zone    = "${var.zone}"

  initial_node_count = "${var.num_vault_servers}"

  min_master_version = "${data.google_container_engine_versions.versions.latest_master_version}"
  node_version       = "${data.google_container_engine_versions.versions.latest_node_version}"

  # Deploy into VPC
  network    = "${google_compute_subnetwork.service_subnet.network}"
  subnetwork = "${google_compute_subnetwork.service_subnet.self_link}"

  # Private GKE
  private_cluster        = true
  master_ipv4_cidr_block = "172.16.0.32/28"
  ip_allocation_policy   = {
    cluster_ipv4_cidr_block = "/20"
    services_ipv4_cidr_block = "/22"
  }

  # Hosts authorized to connect to the cluster master
  master_authorized_networks_config = {
    cidr_blocks = [
      {
        cidr_block = "110.174.101.135/32",
        display_name = "Matt Home"
      },
      {
        cidr_block = "49.183.51.175/32",
        display_name = "OPT_A29F_5GHz"
      },
      {
        cidr_block = "1.136.108.64/32",
        display_name = "T4GXP_MFG7 4G"
      },
    ]
  }

  logging_service    = "${var.kubernetes_logging_service}"
  monitoring_service = "${var.kubernetes_monitoring_service}"

  node_config {
    machine_type    = "${var.instance_type}"
    service_account = "${google_service_account.vault-server.email}"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    tags = ["vault"]
  }

  depends_on = [
    "google_project_service.service",
    "google_kms_crypto_key_iam_member.vault-init",
    "google_storage_bucket_iam_member.vault-server",
    "google_project_iam_member.service-account",
  ]
}

# Provision Global Static IP
resource "google_compute_address" "vault" {
  name    = "vault-lb"
  region  = "${var.region}"
  project = "${google_project.vault.project_id}"

  depends_on = ["google_project_service.service"]
}

output "address" {
  value = "${google_compute_address.vault.address}"
}

output "project" {
  value = "${google_project.vault.project_id}"
}

output "region" {
  value = "${var.region}"
}

output "zone" {
  value = "${var.zone}"
}
