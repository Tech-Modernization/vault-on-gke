
locals {
  exec_pod      = "vault-cluster-0"
  curl          = "kubectl exec ${local.exec_pod} -- curl --cacert /etc/vault/tls/ca.pem -H \"X-Vault-Token: ${var.vault_token}\""
}

resource "null_resource" "enable-services" {
  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
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
}

resource "null_resource" "configure-services" {
  depends_on = [
    "null_resource.enable-services"
  ]

  triggers {
    service_account_key_ttl     = "${var.service_account_key_ttl}"
    service_account_key_max_ttl = "${var.service_account_key_max_ttl}"
  }

  provisioner "local-exec" {
    command = "${local.curl} --data '{ \"ttl\": \"${var.service_account_key_ttl}\", \"max_ttl\": \"${var.service_account_key_max_ttl}\" }' https://127.0.0.1:8200/v1/gcp/config"
  }
}
