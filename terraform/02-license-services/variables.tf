variable "region" {
  type    = "string"
  default = "australia-southeast1"
}

variable "vault_project_id" {
  description   = "The name of the project where vault is located"
  type          = "string"
}

variable "vault_token" {
  description   = "Vault token to use to configure vault"
  type          = "string"
}

variable "vault_cluster_name" {
  description = "The cluster vault is deployed to that will be configured"
  type        = "string"
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
