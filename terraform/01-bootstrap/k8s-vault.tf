# Build Vault enterprise docker image
resource "null_resource" "build-vault-image" {
  provisioner "local-exec" {
    command = <<EOF
cd ../docker-vault/0.X && \
    docker build \
        --build-arg VAULT_VERSION=0.11.1 \
        -t vault-enterprise:0.11.1 .
EOF
  }
}

# Push to Vault image to project gcr.io
resource "null_resource" "push-vault-image-to-gcr" {
  triggers {
    project_id = "${data.google_project.vault.project_id}"
  }

  provisioner "local-exec" {
    command = <<EOF
# authenticate gcloud cli tools
gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

# tag and push
docker tag "vault-enterprise:0.11.1" "gcr.io/${data.google_project.vault.project_id}/vault-enterprise:0.11.1"
docker push "gcr.io/${data.google_project.vault.project_id}/vault-enterprise:0.11.1"
EOF
  }

  depends_on = [
    "null_resource.build-vault-image",
  ]
}

# Write TLS certs to kubernetes secrets
resource "kubernetes_secret" "vault-tls" {
  metadata {
    name = "vault-tls"
  }

  data {
    "vault.crt" = "${tls_locally_signed_cert.vault.cert_pem}\n${tls_self_signed_cert.vault-ca.cert_pem}"
    "vault.key" = "${tls_private_key.vault.private_key_pem}"
    "ca.pem"    = "${tls_self_signed_cert.vault-ca.cert_pem}"
  }
}

# Write the Vault license key to kubernetes secrets
resource "kubernetes_secret" "vault-data" {
  metadata {
    name = "vault-data"
  }

  data {
    "vault.license.json" = "{ \"text\": \"${chomp(file(var.vault_license_path))}\" }"
  }
}

# Write kubernetes configmap. These values are used in the Vault config file
resource "kubernetes_config_map" "vault" {
  metadata {
    name = "vault"
  }

  data {
    load_balancer_address = "${data.google_compute_address.vault.address}"
  }
}

# Render the Vault YAML file
data "template_file" "vault" {
  template = "${file("${path.module}/../../k8s/vault.yaml")}"

  vars {
    load_balancer_ip          = "${data.google_compute_address.vault.address}"
    internal_load_balancer_ip = "${google_compute_address.vault-internal.address}"
    num_vault_servers         = "${var.num_vault_servers}"
    project_id                = "${data.google_project.vault.project_id}"
    region                    = "${var.region}"
    vault_seal                = "${google_kms_crypto_key.vault-seal.name}"
  }
}

# Submit the kubernetes config with kubectl
resource "null_resource" "apply-vault" {
  triggers {
    host                   = "${md5(data.google_container_cluster.vault.endpoint)}"
    username               = "${md5(data.google_container_cluster.vault.master_auth.0.username)}"
    password               = "${md5(data.google_container_cluster.vault.master_auth.0.password)}"
    client_certificate     = "${md5(data.google_container_cluster.vault.master_auth.0.client_certificate)}"
    client_key             = "${md5(data.google_container_cluster.vault.master_auth.0.client_key)}"
    cluster_ca_certificate = "${md5(data.google_container_cluster.vault.master_auth.0.cluster_ca_certificate)}"
    vault_template         = "${md5(data.template_file.vault.rendered)}"
  }

  provisioner "local-exec" {
    command = <<EOF
# authenticate gcloud cli tools
gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

gcloud container clusters get-credentials "${data.google_container_cluster.vault.name}" --zone="${data.google_container_cluster.vault.zone}" --project="${data.google_container_cluster.vault.project}"

CONTEXT="gke_${data.google_container_cluster.vault.project}_${data.google_container_cluster.vault.zone}_${data.google_container_cluster.vault.name}"
echo '${base64encode(data.template_file.vault.rendered)}' | base64 --decode | kubectl apply --context="$CONTEXT" -f -
EOF
  }

  # GKE cluster must be ready
  # Vault image must be in GCR
  # Consul must be setup
  depends_on = [
    "module.vault-cluster",
    "google_kms_crypto_key_iam_member.vault-seal",
    "kubernetes_secret.vault-tls",
    "kubernetes_config_map.vault",

    "null_resource.push-vault-image-to-gcr",
    "null_resource.wait-for-consul-ready",
  ]
}

# Wait for Vault to be up and waiting for initialisation
resource "null_resource" "wait-for-vault-startup" {
  provisioner "local-exec" {
    command = <<EOF
for i in {1..15}; do
  sleep $i
  if kubectl logs vault-cluster-0 | grep "security barrier not initialized"; then
    exit 0
  fi
done

echo "Vault pods are not ready after 2m"
exit 1
EOF
  }

  depends_on = [
    "null_resource.apply-vault"
  ]
}

# Vault init
resource "null_resource" "vault-init" {
  provisioner "local-exec" {
    command = <<EOF
# authenticate gcloud cli tools
gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

gcloud container clusters get-credentials "${data.google_container_cluster.vault.name}" --zone="${data.google_container_cluster.vault.zone}" --project="${data.google_container_cluster.vault.project}"

kubectl exec vault-cluster-0 -- \
  vault operator init \
    -stored-shares=1 \
    -recovery-shares=1 \
    -recovery-threshold=1 \
    -key-shares=1 \
    -key-threshold=1 \
    -ca-cert /etc/vault/tls/ca.pem

# reboot secondary Vault nodes
kubectl exec vault-cluster-1 -- pkill vault
kubectl exec vault-cluster-2 -- pkill vault
EOF
  }

  depends_on = [
    "null_resource.wait-for-vault-startup",
  ]
}
