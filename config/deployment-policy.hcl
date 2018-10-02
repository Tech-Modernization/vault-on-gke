path "auth/approle/login" {
  capabilities = [ "create", "read" ]
}

path "gcp/key/terraform" {
  capabilities = [ "read" ]
}
