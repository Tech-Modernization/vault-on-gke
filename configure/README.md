# Vault Configuration

- Enables GCP Secrets engine
- Configures vault to create terraform service account in the terraform state project and service account keys
- Creates a `bamboo` AppRole, Role ID and Secret

## Notes

Manually add organisation administrator to the vault server service account:

```
export ORG_ID=931373029707
export VAULT_SERVICE_ACCOUNT=vault-server@vault-010e98cf0ff74b4d.iam.gserviceaccount.com
gcloud organizations add-iam-policy-binding "$ORG_ID" \
    --member "serviceAccount:$VAULT_SERVICE_ACCOUNT" \
    --role "roles/resourcemanager.organizationAdmin"
```
