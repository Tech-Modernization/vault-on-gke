# WIP

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
