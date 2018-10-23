
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
    command = "${local.curl} --data '{ \"type\": \"userpass\" }' https://127.0.0.1:8200/v1/sys/auth/userpass"
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
    org_admin_credentials       = "${md5(chomp(file(var.org_admin_credentials)))}"
  }

  provisioner "local-exec" {
    command = "gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
  }

  provisioner "local-exec" {
    # Credentials needs to be single line json with escaped quotes '\"' and double escaped '\\n' such that the payload looks
    # like "{ \"type\": \"service_account\", \"project_id\": \"project-123456\", ...}"
    # - Refer to: https://www.vaultproject.io/api/auth/gcp/index.html#sample-payload
    # - Remove carriage returns to payload on a single line
    # - find replace '"' => '\n'
    # - find replace '\n' => '\\n'
    # TODO Wish the API accepted base64 credentials value or find a `sed` guru to preprocess the credentials
    command = "${local.curl} --data '{ \"ttl\": \"${var.service_account_key_ttl}\", \"max_ttl\": \"${var.service_account_key_max_ttl}\", \"credentials\": \"${chomp(file(var.org_admin_credentials))}\" }' https://127.0.0.1:8200/v1/gcp/config"
  }
}
