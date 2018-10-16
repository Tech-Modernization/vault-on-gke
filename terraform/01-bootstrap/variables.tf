variable "region" {
  type    = "string"
  default = "australia-southeast1"
}

variable "project_id" {
  description = "The service project ID containing the service account."
}

variable "host_project_id" {
  description = "The host project."
}

variable "shared_vpc_name" {
  description = "Shared VPC Name."
}

variable "instance_type" {
  type    = "string"
  default = "n1-standard-2"
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

variable "external_address" {
  description = "The pre created external IP address to bind the LB to"
  type        = "string"
  default     = "vault-lb"
}
