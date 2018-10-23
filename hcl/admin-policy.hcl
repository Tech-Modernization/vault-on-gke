# Allow full access to the system backend
#path "sys/*" {
#  capabilities = ["create", "read", "update", "delete", "list"]
#}

# Manage policies
path "secret/policy" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage Google Cloud Secret rolesets
path "gcp/roleset/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage Google Cloud Secret configuration
path "gcp/config" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Regenerate
#path "/sys/generate-root" {
#  capabilities = ["create", "read", "update", "delete"]
#}
