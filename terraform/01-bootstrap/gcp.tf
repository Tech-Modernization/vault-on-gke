data "google_project" "vault" {
  project_id = "${var.project_id}"
}

data "google_compute_address" "vault" {
  name  = "vault-lb"
  project = "${data.google_project.vault.project_id}"
}

data "google_compute_subnetwork" "subnet" {
  project = "${var.host_project_id}"
  name    = "${data.google_project.vault.project_id}-subnet-gke" # By convention and a bit fragile, if subnet naming convention changes this needs to change
}

# Reserve an internal IP address
resource "google_compute_address" "vault-internal" {
  name            = "vault-lb-internal"
  region          = "${var.region}"
  address_type    = "INTERNAL"
  project         = "${data.google_project.vault.project_id}"
  subnetwork      = "${data.google_compute_subnetwork.subnet.self_link}"
}

# Create the KMS key ring
resource "google_kms_key_ring" "vault-seal" {
  name     = "vault-keyring"
  location = "${var.region}"
  project  = "${data.google_project.vault.project_id}"
}

# https://www.terraform.io/docs/providers/google/r/google_kms_crypto_key.html
# CryptoKeys cannot be deleted from Google Cloud Platform. Destroying a Terraform-managed CryptoKey will remove it
# from state and delete all CryptoKeyVersions, rendering the key unusable, but will not delete the resource on the server.
resource "random_id" "key_suffix" {
  byte_length = 3
}

# Create the crypto key for encrypting auto-unseal keys
resource "google_kms_crypto_key" "vault-seal" {
  name            = "vault-seal-${random_id.key_suffix.hex}"
  key_ring        = "${google_kms_key_ring.vault-seal.id}"
  rotation_period = "604800s"
}

# Grant service account access to the key
resource "google_kms_crypto_key_iam_member" "vault-seal" {
  crypto_key_id = "${google_kms_crypto_key.vault-seal.id}"
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${module.vault-cluster.node_service_account_email}"
}

module "vault-cluster" {
  source                  = "git::https://github.service.anz/ics/terraform-gcp-modules.git//resource-gke-regional-cluster?ref=1d7a368"
  region                  = "${var.region}"
  project_id              = "${data.google_project.vault.project_id}"
  host_project_id         = "${var.host_project_id}"
  shared_vpc_name         = "${var.shared_vpc_name}"
  master_ipv4_cidr_block  = "10.149.16.48/28"

  initial_node_count = "${var.num_vault_servers}"

  node_instance_type = "${var.instance_type}"

  node_service_account_roles = [
    "roles/viewer"
  ]

  oauth_scopes = [
    "cloud-platform"
  ]

  # TODO Implement and test
  #  logging_service    = "${var.kubernetes_logging_service}"
  #  monitoring_service = "${var.kubernetes_monitoring_service}"

  master_authorized_cidr_blocks = [
    { cidr_block = "10.186.0.0/15"        display_name = "ANZ 833 workstations and WiFi" },
    { cidr_block = "59.154.134.121/32",   display_name = "Alteon App Internet Proxy" },

    { cidr_block = "1.136.0.0/16",        display_name = "T4GXP_MFG7 4G Range 1" },
    { cidr_block = "1.152.0.0/16",        display_name = "T4GXP_MFG7 4G Range 2" },
    { cidr_block = "203.110.0.0/16",      display_name = "T4GXP_MFG7 4G Range 3" },
  ]

  default_node_pool_tags = [
    "${var.project_id}-pool"
  ]
}

# Used to obtain master authentication details and location for kubectl which is not exposed by the module
data "google_container_cluster" "vault" {
  project   = "${module.vault-cluster.project_id}"
  name      = "${module.vault-cluster.cluster_name}"
  region    = "${module.vault-cluster.region}"
}

output "address" {
  value = "${data.google_compute_address.vault.address}"
}

output "project" {
  value = "${data.google_project.vault.project_id}"
}

output "vault_service_account" {
  value = "${module.vault-cluster.node_service_account_email}"
}
