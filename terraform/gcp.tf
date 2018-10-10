data "google_project" "vault" {
  project_id = "${var.project_id}"
}

data "google_compute_address" "vault" {
  name  = "vault-lb"
  project = "${data.google_project.vault.project_id}"
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
  source                  = "git::https://github.service.anz/ics/terraform-gcp-modules.git//resource-gke-regional-cluster?ref=bd5ca66"
  region                  = "${var.region}"
  project_id              = "${data.google_project.vault.project_id}"
  host_project_id         = "${var.host_project_id}"
  shared_vpc_name         = "${var.shared_vpc_name}"
  master_ipv4_cidr_block  = "172.16.0.32/28"

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
    { cidr_block = "1.136.104.130/32", display_name = "T4GXP_MFG7 4G" },
    # TODO Add bamboo addresses
#        { cidr_block = "0.0.0.0/0" } # Cloud build and local access
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
