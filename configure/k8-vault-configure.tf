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
    envconsul              = "${md5(data.template_file.envconsul.rendered)}"
    bootstrap              = "${md5(data.template_file.vault-configure.rendered)}"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${data.google_container_cluster.vault.name} --zone ${data.google_container_cluster.vault.zone} --project ${data.google_container_cluster.vault.project}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.vault-configure.rendered}'| kubectl apply -f -"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.envconsul.rendered}'| kubectl apply -f -"
  }
}

data "template_file" "envconsul" {
  template = "${file("${path.module}/../k8s/envconsul.yaml")}"

  vars {
    project_id          = "${data.google_project.vault.project_id}"
    vault_token         = "${var.vault_token}"
  }
}

data "template_file" "terraform-roles" {
  template = "${file("${path.module}/../config/terraform-roles.hcl")}"

  vars {
    org_id              = "${data.google_organization.org.id}"
    tf_state_project_id = "${data.google_project.terraform-state.project_id}"
  }
}

data "template_file" "vault-configure" {
  template = "${file("${path.module}/../k8s/vault-configure.yaml")}"

  vars {
    org_id              = "${data.google_organization.org.id}"
    project_id          = "${data.google_project.vault.project_id}"
    tf_state_project_id = "${data.google_project.terraform-state.project_id}"
    tf_state_bindings   = "${base64encode(data.template_file.terraform-roles.rendered)}"
    vault_token         = "${var.vault_token}"
  }
}
