data "google_service_account" "vault-server" {
  account_id = "${var.vault_service_account}"
  project = "${var.vault_project_id}"
}

# FIXME Require organisation admin priv's to create a terraform user
#resource "google_organization_iam_member" "terraform-state" {
#  count   = "${length(var.tf_state_account_manage_org_iam_roles)}"
#  org_id = "${data.google_organization.org.id}"
#  role    = "${element(var.tf_state_account_manage_org_iam_roles, count.index)}"
#  member  = "serviceAccount:${google_service_account.vault-server.email}"
#}

resource "google_project_iam_member" "terraform-state" {
  count   = "${length(var.tf_state_account_manage_project_iam_roles)}"
  project = "${data.google_project.terraform-state.project_id}"
  role    = "${element(var.tf_state_account_manage_project_iam_roles, count.index)}"
  member  = "serviceAccount:${data.google_service_account.vault-server.email}"
}
