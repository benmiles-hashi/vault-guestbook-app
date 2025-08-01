terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">=3.0.0"
    }
  }
}

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
  namespace = var.vault_namespace
}

# ── 1) Mount the JWT/OIDC auth method ─────────────────────────────────────────
resource "vault_jwt_auth_backend" "github_actions" {
  path               = "jwt-github-actions"
  description        = "OIDC Auth for GitHub Actions"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"

  tune {
    default_lease_ttl = "300s"
  }
}

# ── 2) Define your GitHub Actions role ────────────────────────────────────────
resource "vault_jwt_auth_backend_role" "ci_pipeline" {
  backend             = vault_jwt_auth_backend.github_actions.path
  role_name           = "ci-pipeline"
  role_type           = "jwt"
  user_claim          = "sub"
  bound_audiences     = ["https://github.com/benmiles-hashi"]
  bound_claims_type   = "glob"
  bound_claims = {
    repository = "benmiles-hashi/vault-guestbook-app"
  }

  token_policies      = ["default", "demo", "sys-mounts-read", "tfc-token-consumer"]
  token_ttl           = 1800        # 30 minutes
  token_max_ttl       = 3600        # 1 hour (optional)
  token_type          = "service"
}
resource "vault_policy" "kv_rw_list" {
  name   = "kv-rw-list-all"
  policy = <<EOT
        # Allow full CRUD + list on all KV v2 data
        path "secret/data/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
        }

        # Allow listing keys (metadata) in the KV mount
        path "secret/metadata/*" {
        capabilities = ["list"]
        }
    EOT
}
resource "vault_policy" "tfc_creds" {
  name   = "tfc-token-consumer"
  policy = <<EOT
        path "terraform-github/creds/*" {
        capabilities = ["read"]
        }
    EOT
}
resource "vault_policy" "mounts_list" {
  name   = "sys-mounts-read"
  policy = <<EOT
    # Allow listing all mounted secret engines
    path "sys/mounts" {
    capabilities = ["list","read"]
    }
    # Allow reading each mount’s details
    path "sys/mounts/*" {
    capabilities = ["read"]
    }
    EOT
}

resource "vault_mount" "terraform" {
  path = "terraform-github"
  type = "terraform"
}

###############################
# 2) Configure access to TFC
###############################
# This writes to POST /v1/terraform/config
resource "vault_generic_endpoint" "terraform_config" {
  path      = "${vault_mount.terraform.path}/config"
  data_json = jsonencode({
    address = "https://app.terraform.io"    # change if on-prem TFE
    token   = var.initial_tfc_token         # a long-lived token you supply once
  })
}

###############################
# 3) Define a role for short-lived user tokens
###############################
# This writes to POST /v1/terraform/role/ci
resource "vault_generic_endpoint" "terraform_role_ci" {
  path      = "${vault_mount.terraform.path}/role/ci"
  data_json = jsonencode({
    user_id         = var.tfc_user_id       # e.g. "user-MA4GL63FmYRpSFxa"
    credential_type = "user"                # could also be "team" or "organization"
    ttl             = "15m"                 # tokens valid for 15 minutes
    max_ttl         = "1h"                  # renewable up to 1 hour
  })
}

/* ###############################
# 4) Read out a dynamic token
###############################
# This reads from GET /v1/terraform/creds/ci
data "vault_generic_secret" "tfc_ci" {
  path = "${vault_mount.terraform.path}/creds/ci"
}

output "tfc_token" {
  value = data.vault_generic_secret.tfc_ci.data["token"]
}
 */