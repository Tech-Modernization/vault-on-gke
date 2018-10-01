variable "region" {
  type    = "string"
  default = "australia-southeast1"
}

variable "billing_account" {
  type = "string"
}

variable "org" {
  type = "string"
}

variable "instance_type" {
  type    = "string"
  default = "n1-standard-2"
}

variable "service_account_iam_roles" {
  type = "list"

  default = [
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.serviceAccountTokenCreator",
    "roles/iam.serviceAccountUser",
    "roles/viewer",
  ]
}

variable "project_services" {
  type = "list"

  default = [
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
  ]
}

variable "kubernetes_logging_service" {
  type    = "string"
  default = "logging.googleapis.com/kubernetes"
}

variable "kubernetes_monitoring_service" {
  type    = "string"
  default = "monitoring.googleapis.com/kubernetes"
}

variable "num_vault_servers" {
  type    = "string"
  default = "3"
}

variable "consul_license_path" {
  description = "Path to Consul's license file"
  type        = "string"
}

variable "vault_license_path" {
  description = "Path to Vault's license file"
  type        = "string"
}
