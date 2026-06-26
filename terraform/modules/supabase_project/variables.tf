# modules/supabase_project/variables.tf
# Variables d'entrée du module. Un projet Supabase est créé par workspace
# (dev / staging / production). Le nom est suffixé par l'environnement
# depuis le module racine pour éviter les collisions dans le dashboard.

variable "project_name" {
  description = "Nom complet du projet Supabase (ex: vtc-demo-dev)"
  type        = string
}

variable "organization_id" {
  description = "ID de l'organisation Supabase cible"
  type        = string
}

variable "database_password" {
  description = "Mot de passe administrateur PostgreSQL du projet (pas de @, :, /, ?, # — doivent être encodés URI)"
  type        = string
  sensitive   = true

  validation {
    # ponytail: rejette les chars qui briseraient l'URL postgresql://user:pass@host/db
    condition     = !can(regex("[@:/?#\\[\\]@!$&'()*+,;=%]", var.database_password))
    error_message = "Le mot de passe ne doit pas contenir de caractères spéciaux URL (@, :, /, ?, #, [, ], !, $, &, ', (, ), *, +, ,, ;, =, %). Utiliser des lettres, chiffres, - et _ uniquement."
  }
}

variable "region" {
  description = "Région Supabase du projet (ex: eu-west-3 pour Paris)"
  type        = string
  default     = "eu-west-3"
}
