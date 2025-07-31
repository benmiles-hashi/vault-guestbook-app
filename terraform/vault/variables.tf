variable "vault_addr" {
  type        = string
  description = "HCP Vault endpoint"
}

variable "vault_token" {
  type        = string
  description = "Vault root or service token"
  sensitive   = true
}

variable "vault_namespace" {
  type        = string
  description = "Vault namespace"
    default= "admin"
}