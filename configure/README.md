# Vault Configuration

- Enables GCP Secrets engine
- Configures vault to create terraform service account in the terraform state project and service account keys
- Creates a `bamboo` AppRole, Role ID and Secret

## Notes

Needs to be executed by a user that has elevated privileges. The organisation terraform state user is sufficient as long as
command below is executed before this `terraform apply`:

```
export ORG_ID=931373029707
# The cluster nodes service account
export VAULT_SERVICE_ACCOUNT=anz-cs-vault-np-gke-nodes@anz-cs-vault-np-a55471.iam.gserviceaccount.com
gcloud organizations add-iam-policy-binding "$ORG_ID" \
    --member "serviceAccount:$VAULT_SERVICE_ACCOUNT" \
    --role "roles/resourcemanager.organizationAdmin"
```
