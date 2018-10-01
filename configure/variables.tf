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

variable "vault_token" {
  description   = "Vault token to use to configure vault"
  type          = "string"
}

variable "terraform_state_project_id" {
  description = "Destination project for service accounts"
  type        = "string"
}
