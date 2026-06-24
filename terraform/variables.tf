# variables.tf
# Centralise toutes les variables d'entrée du module racine.
# Les valeurs sensibles (tokens, IDs) ne doivent JAMAIS avoir de default ici :
# Terraform les demandera en interactif ou les lira depuis TF_VAR_* en CI.

variable "cloudflare_api_token" {
  description = "Token API Cloudflare avec les permissions Pages:Edit et Zone:Read"
  type        = string
  sensitive   = true # Masque la valeur dans les logs Terraform
}

variable "cloudflare_account_id" {
  description = "ID du compte Cloudflare (visible dans l'URL du dashboard)"
  type        = string
}

variable "project_name" {
  description = "Nom de base du projet Cloudflare Pages (ex: vtc-dashboard)"
  type        = string
  default     = "vtc-demo"
}

variable "github_owner" {
  description = "Organisation ou utilisateur GitHub propriétaire du dépôt source"
  type        = string
}

variable "github_repo_name" {
  description = "Nom du dépôt GitHub contenant le code source de l'application"
  type        = string
}
