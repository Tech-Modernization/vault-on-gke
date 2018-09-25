# Build Consul enterprise docker image
resource "null_resource" "build-consul-image" {
  provisioner "local-exec" {
    command = <<EOF
cd ../docker-consul/0.X && \
    docker build \
        --build-arg CONSUL_VERSION=1.2.3 \
        -t consul-enterprise:1.2.3 .
EOF
  }
}

# Push to Consul image to project gcr.io
resource "null_resource" "push-consul-image-to-gcr" {
  triggers {
    project_id = "${google_project.vault.project_id}"
  }

  provisioner "local-exec" {
    command = <<EOF
docker tag "consul-enterprise:1.2.3" "gcr.io/${google_project.vault.project_id}/consul-enterprise:1.2.3"
docker push "gcr.io/${google_project.vault.project_id}/consul-enterprise:1.2.3"
EOF
  }

  depends_on = [
    "null_resource.build-consul-image",
  ]
}

# Write Consul license to kubernetes secrets
resource "kubernetes_secret" "consul-license" {
  metadata {
    name = "consul-license"
  }

  data {
    "consul.license" = "${file(var.consul_license_path)}"
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
  # Consul license must be available in kubernetes
  # Consul image must be in GCR
  depends_on = [
    "google_container_node_pool.vault",
    "kubernetes_secret.consul-license",
    "null_resource.push-consul-image-to-gcr",
  ]
}

# Wait for Consul to be ready
resource "null_resource" "wait-for-consul-ready" {
  provisioner "local-exec" {
    command = <<EOF
for i in {1..15}; do
  sleep $i
  if [ $(kubectl get pod | grep -E "consul-cluster.*1/1.*Running" | wc -l) -eq 3 ]; then
    exit 0
  fi
done

echo "Consul pods are not ready after 2m"
exit 1
EOF
  }

  depends_on = ["null_resource.apply-consul"]
}

# License Consul
resource "null_resource" "consul-license" {
  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.vault.name}" --zone="${google_container_cluster.vault.zone}" --project="${google_container_cluster.vault.project}"

kubectl exec consul-cluster-0 -- sh -c 'consul license put @/consul/license/consul.license'
EOF
  }

  depends_on = ["null_resource.wait-for-consul-ready"]
}
