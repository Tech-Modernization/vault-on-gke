data "google_organization" "org" {
  domain = "${var.org}"
}

data "google_project" "vault" {
  project_id = "${var.vault_project_id}"
}

data "google_container_cluster" "vault" {
  project   = "${data.google_project.vault.project_id}"
  name      = "vault"
  zone      = "${var.zone}"
}

data "google_project" "terraform-state" {
  project_id = "${var.terraform_state_project_id}"
}

resource "null_resource" "configure-vault" {
  triggers {
    bamboo_policy             = "${md5(data.local_file.bamboo-policy.content)}"
    terraform_state_project   = "${data.google_project.terraform-state.project_id}"
    terraform_roles           = "${md5(data.template_file.terraform-roles.rendered)}"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" --data '{ \"type\": \"approle\" }' https://127.0.0.1:8200/v1/sys/auth/approle"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" --data '{ \"type\": \"gcp\" }' https://127.0.0.1:8200/v1/sys/mounts/gcp"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" --data '{ \"ttl\": \"15m\", \"max_ttl\": \"15m\" }' https://127.0.0.1:8200/v1/gcp/config"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" --data '{ \"secret_type\": \"service_account_key\", \"project\": \"${data.google_project.terraform-state.project_id}\", \"bindings\": \"${base64encode(data.template_file.terraform-roles.rendered)}\" }' https://127.0.0.1:8200/v1/gcp/roleset/terraform"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" -X PUT --data '{ \"policy\": \"${base64encode(data.local_file.bamboo-policy.content)}\" }' https://127.0.0.1:8200/v1/sys/policy/bamboo"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" --data '{ \"policies\": \"bamboo\" }' https://127.0.0.1:8200/v1/auth/approle/role/bamboo"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" https://127.0.0.1:8200/v1/auth/approle/role/bamboo/role-id"
  }

  provisioner "local-exec" {
    command = "kubectl exec vault-cluster-0 -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\" -X POST https://127.0.0.1:8200/v1/auth/approle/role/bamboo/secret-id"
  }
}

data "template_file" "terraform-roles" {
  template = "${file("${path.module}/../config/terraform-roles.hcl")}"

  vars {
    org_id              = "${data.google_organization.org.id}"
    tf_state_project_id = "${data.google_project.terraform-state.project_id}"
  }
}

data "local_file" "bamboo-policy" {
  filename = "${"${path.module}/../config/bamboo-policy.hcl"}"
}
