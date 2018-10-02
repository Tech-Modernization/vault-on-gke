variable "region" {
  type    = "string"
  default = "australia-southeast1"
}

variable "zone" {
  type    = "string"
  default = "australia-southeast1-a"
}

variable "org" {
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
