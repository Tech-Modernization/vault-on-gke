# Vault license
resource "null_resource" "vault-license" {
  provisioner "local-exec" {
    command = <<EOF
# authenticate gcloud cli tools
gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

gcloud container clusters get-credentials "${data.google_container_cluster.vault.name}" --zone="${data.google_container_cluster.vault.zone}" --project="${data.google_container_cluster.vault.project}"

# install Vault license (which is mounted into Vault container via k8s secrets)
kubectl exec vault-cluster-0 -- \
  curl -X PUT \
    -H "X-Vault-Token: ${var.vault_token}" \
    --cacert /etc/vault/tls/ca.pem \
    --data @/etc/vault/data/vault.license.json \
    https://localhost:8200/v1/sys/license
EOF
  }
}
