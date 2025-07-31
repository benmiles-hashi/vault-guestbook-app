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
  bound_audiences     = ["api://Actions"]
  bound_claims_type   = "glob"
  bound_claims = {
    repository = "benmiles-hashi/vault-guestbook-app"
  }

  token_policies      = ["default"]
  token_ttl           = 1800        # 30 minutes
  token_max_ttl       = 3600        # 1 hour (optional)
  token_type          = "service"
}