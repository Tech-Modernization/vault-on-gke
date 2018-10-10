# Vault Configuration

- Enables GCP Secrets engine
- Configures vault to create terraform service account in the terraform state project and service account keys
- Creates a `bamboo` AppRole, Role ID and Secret

## Usage

1. Set all variables:

```
# Owning organisation
organisation_id = "931373029707"
# Terraform state project where managed service accounts will be created
terraform_state_project_id = "anzod-tf-state-931373029707"
# The vault service project
vault_project_id = "anz-cs-vault-np-cc93f0"
# Service account that will be creating managed service accounts
vault_service_account = "anz-cs-vault-np-gke-nodes"
# The root token of vault
vault_token = "2QHbO3ZG6cnBoPjYCFpQg5mT"
# The cluster where vault is deployed
vault_cluster_name = "anz-cs-vault-np-gke"
```

2. Manually (tech debt) update the vault cluster nodes service account to have organisation admin privileges. This is to allow vault to grant
   organisation level IAMs to the managed terraform state service account.
   

```
# Owning organisation
export ORG_ID=931373029707
# The cluster nodes service account
export VAULT_SERVICE_ACCOUNT=anz-cs-vault-np-gke-nodes@anz-cs-vault-np-a55471.iam.gserviceaccount.com
gcloud organizations add-iam-policy-binding "$ORG_ID" \
    --member "serviceAccount:$VAULT_SERVICE_ACCOUNT" \
    --role "roles/resourcemanager.organizationAdmin"
```

3. Execute the plan (`terraform apply`)
