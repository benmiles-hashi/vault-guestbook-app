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
variable "initial_tfc_token" {
    type        = string
  description = "TFC Initial Token"
}
variable "tfc_user_id" {
  type        = string
  description = "tfc user"
}
