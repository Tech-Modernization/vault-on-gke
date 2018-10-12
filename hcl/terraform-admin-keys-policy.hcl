path "auth/approle/login" {
  capabilities = [ "create", "read" ]
}

path "gcp/key/${roleset_key_name}" {
  capabilities = [ "read" ]
}
