# Pull Vault image and push to gcr.io
resource "null_resource" "gcr-vault" {
  triggers {
    project_id = "${google_project.vault.project_id}"
  }

  provisioner "local-exec" {
    command = <<EOF
docker pull "vault:0.11.1"
docker tag "vault:0.11.1" "gcr.io/${google_project.vault.project_id}/vault:0.11.1"
docker push "gcr.io/${google_project.vault.project_id}/vault:0.11.1"
EOF
  }
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

# Write kubernetes configmap. These values are used in the Vault config file
resource "kubernetes_config_map" "vault" {
  metadata {
    name = "vault"
  }

  data {
    load_balancer_address = "${google_compute_address.vault.address}"
  }
}

# Render the Vault YAML file
data "template_file" "vault" {
  template = "${file("${path.module}/../k8s/vault.yaml")}"

  vars {
    load_balancer_ip  = "${google_compute_address.vault.address}"
    num_vault_servers = "${var.num_vault_servers}"
    project_id        = "${google_project.vault.project_id}"
  }
}

# Submit the kubernetes config with kubectl
resource "null_resource" "apply-vault" {
  triggers {
    host                   = "${md5(google_container_cluster.vault.endpoint)}"
    username               = "${md5(google_container_cluster.vault.master_auth.0.username)}"
    password               = "${md5(google_container_cluster.vault.master_auth.0.password)}"
    client_certificate     = "${md5(google_container_cluster.vault.master_auth.0.client_certificate)}"
    client_key             = "${md5(google_container_cluster.vault.master_auth.0.client_key)}"
    cluster_ca_certificate = "${md5(google_container_cluster.vault.master_auth.0.cluster_ca_certificate)}"
  }

  depends_on = [
    "kubernetes_secret.vault-tls",
    "kubernetes_config_map.vault",
  ]

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault.name}" --zone="${google_container_cluster.vault.zone}" --project="${google_container_cluster.vault.project}"

CONTEXT="gke_${google_container_cluster.vault.project}_${google_container_cluster.vault.zone}_${google_container_cluster.vault.name}"
echo '${base64encode(data.template_file.vault.rendered)}' | base64 --decode | kubectl apply --context="$CONTEXT" -f -
EOF
  }

  # GKE cluster must be ready
  # Vault image must be in GCR
  # Consul must be setup
  depends_on = [
    "google_container_node_pool.vault",
    "null_resource.gcr-vault",
    "null_resource.wait-for-consul-ready",
  ]
}
