data "google_project" "vault" {
  project_id = "${var.vault_project_id}"
}

data "google_container_cluster" "vault" {
  project   = "${data.google_project.vault.project_id}"
  name      = "vault"
  zone      = "${var.zone}"
}

# Pull Vault image and push to gcr.io
resource "null_resource" "gcr-envconsol" {
  triggers {
    project_id = "${data.google_project.vault.project_id}"
  }

  provisioner "local-exec" {
    command = <<EOF
gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS
docker pull "hashicorp/envconsul:0.7.0-alpine"
docker tag "hashicorp/envconsul:0.7.0-alpine" "gcr.io/${data.google_project.vault.project_id}/envconsul:0.7.0-alpine"
docker push "gcr.io/${data.google_project.vault.project_id}/envconsul:0.7.0-alpine"
EOF
  }
}

resource "null_resource" "envconsul" {
  triggers {
    envconsul              = "${md5(data.template_file.envconsul.rendered)}"
  }

  depends_on = [
    "null_resource.gcr-envconsol"
  ]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.envconsul.rendered}'| kubectl apply -f -"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.envconsul.rendered}'| kubectl delete --ignore-not-found=true -f -"
    when    = "destroy"
  }
}

data "template_file" "envconsul" {
  template = "${file("${path.module}/../../k8s/envconsul.yaml")}"

  vars {
    project_id          = "${data.google_project.vault.project_id}"
    vault_token         = "${var.vault_token}"
  }
}
