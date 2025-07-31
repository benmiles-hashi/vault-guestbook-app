provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

# ── Database Secrets Engine ────────────────────────────────────────────────────

# Enable at “database/”
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "MySQL dynamic creds"
}

# Configure MySQL backend connection
resource "vault_database_secret_backend_connection" "mysql" {
  backend         = vault_mount.database.path
  name            = "demo"
  allowed_roles   = ["demo-role"]
  connection_url  = "{{username}}:{{password}}@tcp(${aws_instance.app.private_ip}:3306)/"
  username        = var.db_root_username
  password        = var.db_root_password
}

# Role that grants SELECT+INSERT on guestbook
resource "vault_database_secret_backend_role" "demo_role" {
  backend             = vault_mount.database.path
  name                = "demo-role"
  db_name             = vault_database_secret_backend_connection.mysql.name
  creation_statements = [
    "CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT, INSERT ON demo.guestbook TO '{{name}}'@'%';"
  ]
  default_ttl         = "1m"
  max_ttl             = "5m"
}

# ── PKI Secrets Engine ─────────────────────────────────────────────────────────

# Enable at “pki/”
resource "vault_mount" "pki" {
  path        = "pki"
  type        = "pki"
  description = "TLS certificates"
}

# Generate a self-signed root CA
resource "vault_pki_secret_backend_root_cert" "root_ca" {
  backend     = vault_mount.pki.path
  key_type    = "rsa"
  key_bits    = 4096
  common_name = "demo-vault-root-ca"
  ttl         = "87600h"   # 10 years
}

# Configure URLs for issued certs & CRL
resource "vault_pki_secret_backend_urls" "urls" {
  backend                  = vault_mount.pki.path
  issuing_certificates     = ["http://vault:8200/v1/pki/ca"]
  crl_distribution_points  = ["http://vault:8200/v1/pki/crl"]
}

# Role for issuing webserver certs
resource "vault_pki_secret_backend_role" "webserver" {
  backend          = vault_mount.pki.path
  name             = "webserver"
  allowed_domains  = ["localhost"]
  allow_subdomains = true
  max_ttl          = "72h"
}
