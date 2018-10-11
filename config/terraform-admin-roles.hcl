# Standard terraform user organisation access
resource "//cloudresourcemanager.googleapis.com/organizations/${org_id}" {
  roles = [
    "roles/billing.user",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/compute.xpnAdmin",
    "roles/editor",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/orgpolicy.policyAdmin",
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.projectDeleter",
    "roles/storage.admin"
  ]
}

# Grant access to the terraform state bucket
resource "buckets/${tf_state_project_id}" {
  roles = [
    "roles/storage.admin"
  ]
}
