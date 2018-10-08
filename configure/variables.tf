variable "region" {
  type    = "string"
  default = "australia-southeast1"
}

variable "organisation_id" {
  description = "The owning organisation ID"
  type = "string"
}

variable "vault_project_id" {
  description   = "The name of the project where vault is located"
  type          = "string"
}

variable "vault_service_account" {
  description = "The service account id for the vault project"
}

variable "vault_token" {
  description   = "Vault token to use to configure vault"
  type          = "string"
}

variable "vault_cluster_name" {
  description = "The cluster vault is deployed to that will be configured"
  type        = "string"
}

variable "terraform_state_project_id" {
  description = "Destination project for service accounts"
  type        = "string"
}

# Runner of this terraform needs high organisation privs
variable "tf_state_account_manage_org_iam_roles" {
  type = "list"

  default = [
    "roles/resourcemanager.organizationAdmin"
  ]
}

variable "tf_state_account_manage_project_iam_roles" {
  type = "list"

  default = [
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/storage.admin"
  ]
}

variable "service_account_key_ttl" {
  type          = "string"
  description   = "Specifies default config TTL for long-lived service account keys"
  default       = "15m"
}

variable "service_account_key_max_ttl" {
  description   = "Specifies the maximum config TTL for long-lived service account keys"
  type          = "string"
  default       = "15m"
}

variable "deployment_username" {
  description = "The username of the app that will be obtaining the terraform service account key. This becomes the AppRole RoleID."
  type        = "string"
  default     = "bamboo"
}

variable "rolset_key_name" {
  description = "The name of the roleset in Vault which will have keys generated and managed by Vault."
  type        = "string"
  default     = "deployment"
}
