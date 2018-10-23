
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

  policy_name   = "terraform-admin-keys"
}

resource "null_resource" "configure-admin-roleset" {
  triggers {
    terraform_state_project     = "${var.terraform_state_project_id}"
    terraform_roles             = "${md5(data.template_file.terraform-admin-roles.rendered)}"
    roleset_key_name            = "${var.roleset_key_name}"
  }

  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
  }

  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"secret_type\": \"service_account_key\", \"project\": \"${var.terraform_state_project_id}\", \"bindings\": \"${base64encode(data.template_file.terraform-admin-roles.rendered)}\" }' https://127.0.0.1:8200/v1/gcp/roleset/${var.roleset_key_name}"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X DELETE https://127.0.0.1:8200/v1/gcp/roleset/${var.roleset_key_name}"
    when    = "destroy"
  }
}

resource "null_resource" "configure-admin-keys-policy" {
  depends_on = [
    "null_resource.configure-admin-roleset"
  ]

  triggers {
    deployment_policy           = "${md5(data.template_file.terraform-admin-keys-policy.rendered)}"
  }

  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
  }

  # This is nasty, would probably be better to use vault provider to manage these
  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X PUT --data '{ \"policy\": \"${base64encode(data.template_file.terraform-admin-keys-policy.rendered)}\" }' https://127.0.0.1:8200/v1/sys/policy/${local.policy_name}"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X DELETE https://127.0.0.1:8200/v1/sys/policy/${local.policy_name}"
    when    = "destroy"
  }
}

resource "null_resource" "configure-deployment-user" {
  depends_on = [
    "null_resource.configure-admin-keys-policy"
  ]

  triggers {
    deployment_username     = "${var.deployment_username}"
  }

  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
  }

  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"policies\": \"${local.policy_name}\" }' https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X DELETE https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}"
    when    = "destroy"
  }

  provisioner "local-exec" {
    command = "${local.curl} https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}/role-id"
  }

  provisioner "local-exec" {
    command = "${local.curl} -X POST https://127.0.0.1:8200/v1/auth/approle/role/${var.deployment_username}/secret-id"
  }
}

data "template_file" "terraform-admin-roles" {
  template = "${file("${path.module}/../../hcl/terraform-admin-roles.hcl")}"

  vars {
    org_id              = "${var.organisation_id}"
    tf_state_project_id = "${var.terraform_state_project_id}"
  }
}

data "template_file" "terraform-admin-keys-policy" {
  template = "${file("${path.module}/../../hcl/terraform-admin-keys-policy.hcl")}"

  vars {
    roleset_key_name     = "${var.roleset_key_name}"
  }
}
