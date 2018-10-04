data "google_project" "vault" {
  project_id = "${var.project_id}"
}

data "google_project" "host_project" {
  project_id = "${var.host_project_id}"
}

data "google_compute_subnetwork" "service_subnet" {
  name    = "${data.google_project.vault.project_id}-subnet-gke" # FIXME Change to explicit reference
  project = "${data.google_project.host_project.id}"
}

data "google_compute_address" "vault" {
  name  = "vault-lb"
  project = "${data.google_project.vault.project_id}"
}

# Create the vault service account
resource "google_service_account" "vault-server" {
  account_id   = "vault-server"
  display_name = "Vault Server"
  project      = "${data.google_project.vault.project_id}"
}

# Create a service account key
resource "google_service_account_key" "vault" {
  service_account_id = "${google_service_account.vault-server.name}"
}

# Add the service account to the project
resource "google_project_iam_member" "service-account" {
  count   = "${length(var.service_account_iam_roles)}"
  project = "${data.google_project.vault.project_id}"
  role    = "${element(var.service_account_iam_roles, count.index)}"
  member  = "serviceAccount:${google_service_account.vault-server.email}"
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault-seal" {
  name     = "vault-keyring"
  location = "${var.region}"
  project  = "${data.google_project.vault.project_id}"
}

# Create the crypto key for encrypting auto-unseal keys
resource "google_kms_crypto_key" "vault-seal" {
  name            = "vault-seal"
  key_ring        = "${google_kms_key_ring.vault-seal.id}"
  rotation_period = "604800s"
}

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "vault-seal" {
  crypto_key_id = "${google_kms_crypto_key.vault-seal.id}"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.vault-server.email}"
}

# Get latest cluster version
data "google_container_engine_versions" "versions" {
  zone    = "${var.zone}"
  project = "${data.google_project.vault.project_id}"
}

# Create the GKE cluster
resource "google_container_cluster" "vault" {
  name    = "vault"
  project = "${data.google_project.vault.project_id}"
  zone    = "${var.zone}"

  min_master_version = "${data.google_container_engine_versions.versions.latest_master_version}"
  node_version       = "${data.google_container_engine_versions.versions.latest_node_version}"

  # Deploy into VPC
  network    = "${data.google_compute_subnetwork.service_subnet.network}"
  subnetwork = "${data.google_compute_subnetwork.service_subnet.self_link}"

  # Private GKE
  private_cluster        = true
  master_ipv4_cidr_block = "172.16.0.32/28"
  ip_allocation_policy   = {
    cluster_secondary_range_name  = "${data.google_compute_subnetwork.service_subnet.secondary_ip_range.0.range_name}"
    services_secondary_range_name = "${data.google_compute_subnetwork.service_subnet.secondary_ip_range.1.range_name}"
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
        cidr_block = "1.152.110.151/32",
        display_name = "T4GXP_MFG7 4G"
      },
    ]
  }

  logging_service    = "${var.kubernetes_logging_service}"
  monitoring_service = "${var.kubernetes_monitoring_service}"

  # Declare node pools independently of clusters
  remove_default_node_pool = true

  node_pool = {
    name = "default-pool"
  }

  # Ensure cluster is not recreated when pool configuration changes
  lifecycle = {
    ignore_changes = ["node_pool"]
  }
}

resource "google_container_node_pool" "vault" {
  name    = "default-pool"
  cluster = "${google_container_cluster.vault.name}"
  project = "${data.google_project.vault.project_id}"
  zone    = "${var.zone}"

  initial_node_count = "${var.num_vault_servers}"

  max_pods_per_node = "110" # Kubernetes default

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    image_type      = "COS"
    machine_type    = "${var.instance_type}"
    service_account = "${google_service_account.vault-server.email}"

    workload_metadata_config {
      node_metadata = "SECURE"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    tags = ["vault"]
  }

  depends_on = [
    "google_kms_crypto_key_iam_member.vault-seal",
    "google_project_iam_member.service-account",
  ]
}

output "address" {
  value = "${data.google_compute_address.vault.address}"
}

output "project" {
  value = "${data.google_project.vault.project_id}"
}

output "region" {
  value = "${var.region}"
}

output "zone" {
  value = "${var.zone}"
}

output "vault_service_account" {
  value = "${google_service_account.vault-server.email}"
}
