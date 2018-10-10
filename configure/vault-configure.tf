
data "google_project" "vault" {
  project_id = "${var.vault_project_id}"
}

data "google_container_cluster" "vault" {
  project   = "${data.google_project.vault.project_id}"
  name      = "${var.vault_cluster_name}"
  region    = "${var.region}"
}

locals {
  exec_pod      = "vault-cluster-0"
  curl          = "kubectl exec ${local.exec_pod} -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\""
}

resource "null_resource" "configure-vault" {
  triggers {
    deployment_policy           = "${md5(data.local_file.deployment-policy.content)}"
    terraform_state_project     = "${var.terraform_state_project_id}"
    terraform_roles             = "${md5(data.template_file.terraform-roles.rendered)}"
    service_account_key_ttl     = "${var.service_account_key_ttl}"
    service_account_key_max_ttl = "${var.service_account_key_max_ttl}"
    roleset_key_name            = "${var.rolset_key_name}"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"type\": \"approle\" }' https://127.0.0.1:8200/v1/sys/auth/approle"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"type\": \"gcp\" }' https://127.0.0.1:8200/v1/sys/mounts/gcp"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"ttl\": \"${var.service_account_key_ttl}\", \"max_ttl\": \"${var.service_account_key_max_ttl}\" }' https://127.0.0.1:8200/v1/gcp/config"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"secret_type\": \"service_account_key\", \"project\": \"${var.terraform_state_project_id}\", \"bindings\": \"${base64encode(data.template_file.terraform-roles.rendered)}\" }' https://127.0.0.1:8200/v1/gcp/roleset/${var.rolset_key_name}"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X PUT --data '{ \"policy\": \"${base64encode(data.local_file.deployment-policy.content)}\" }' https://127.0.0.1:8200/v1/sys/policy/deployment"
  }

}

resource "null_resource" "configure-deployment-user" {
  depends_on = [
    "null_resource.configure-vault"
  ]

  triggers {
    deployment_username     = "${var.deployment_username}"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"policies\": \"deployment\" }' https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}"
  }

  provisioner "local-exec" {
    command = "${local.curl} https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}/role-id"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X POST https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}/secret-id"
  }
}

data "template_file" "terraform-roles" {
  template = "${file("${path.module}/../config/terraform-roles.hcl")}"

  vars {
    org_id              = "${var.organisation_id}"
    tf_state_project_id = "${var.terraform_state_project_id}"
  }
}

data "local_file" "deployment-policy" {
  filename = "${"${path.module}/../config/deployment-policy.hcl"}"
}
