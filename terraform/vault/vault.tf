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

  token_policies      = ["default", "demo", "sys-mounts-read"]
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