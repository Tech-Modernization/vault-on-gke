# Pull Consul image and push to gcr.io
resource "null_resource" "gcr-consul" {
  triggers {
    project_id = "${google_project.vault.project_id}"
  }

  provisioner "local-exec" {
    command = <<EOF
docker pull "consul:1.2.3"
docker tag "consul:1.2.3" "gcr.io/${google_project.vault.project_id}/consul:1.2.3"
docker push "gcr.io/${google_project.vault.project_id}/consul:1.2.3"
EOF
  }
}

# Render the Consul YAML file
data "template_file" "consul" {
  template = "${file("${path.module}/../k8s/consul.yaml")}"

  vars {
    project_id = "${google_project.vault.project_id}"
  }
}

# Submit the kubernetes config with kubectl
resource "null_resource" "apply-consul" {
  triggers {
    host     = "${md5(google_container_cluster.vault.endpoint)}"
    username = "${md5(google_container_cluster.vault.master_auth.0.username)}"
    password = "${md5(google_container_cluster.vault.master_auth.0.password)}"
    template = "${md5(data.template_file.consul.rendered)}"
  }

  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault.name}" --zone="${google_container_cluster.vault.zone}" --project="${google_container_cluster.vault.project}"

CONTEXT="gke_${google_container_cluster.vault.project}_${google_container_cluster.vault.zone}_${google_container_cluster.vault.name}"
echo '${data.template_file.consul.rendered}' | kubectl apply --context="$CONTEXT" -f -
EOF
  }

  # GKE cluster must be ready
  # Consul image must be in GCR
  depends_on = [
    "google_container_node_pool.vault",
    "null_resource.gcr-consul",
  ]
}
