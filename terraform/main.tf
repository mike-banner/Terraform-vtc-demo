# main.tf
# Point d'entrée du module racine. Crée un projet Supabase et un projet
# Cloudflare Pages pour le workspace actif, puis injecte l'URL de la base
# de données dans les variables d'environnement de Cloudflare.
#
# Ordre de dépendance garanti par Terraform :
#   supabase_project → (database_url) → cloudflare_pages (env_vars)
#
# Exemples :
#   terraform workspace select dev        → vtc-demo-dev (Supabase + CF Pages)
#   terraform workspace select staging    → vtc-demo-staging
#   terraform workspace select production → vtc-demo-production

# ─── Module Supabase ─────────────────────────────────────────────────────────

module "supabase_project" {
  source = "./modules/supabase_project"

  project_name      = "${var.project_name}-${terraform.workspace}"
  organization_id   = var.supabase_organization_id
  database_password = var.supabase_database_password
  region            = var.supabase_region
}

# ─── Module Cloudflare Pages ─────────────────────────────────────────────────

module "cloudflare_pages" {
  source = "./modules/cloudflare_pages"

  account_id       = var.cloudflare_account_id
  project_name     = "${var.project_name}-${terraform.workspace}"
  github_owner     = var.github_owner
  github_repo_name = var.github_repo_name

  # Domaine personnalisé selon le workspace (lookup retourne "" si clé absente → pas de domaine)
  custom_domain = lookup(var.environment_domains, terraform.workspace, "")

  # Lien magique : l'URL Supabase est injectée automatiquement dans Cloudflare Pages.
  # Terraform garantit que supabase_project est créé AVANT cloudflare_pages.
  env_vars = {
    DATABASE_URL                  = module.supabase_project.database_url
    SUPABASE_URL                  = module.supabase_project.api_url
    NEXT_PUBLIC_SUPABASE_URL      = module.supabase_project.api_url
    PUBLIC_SUPABASE_URL           = module.supabase_project.api_url
    NEXT_PUBLIC_SUPABASE_ANON_KEY = var.supabase_anon_key
    PUBLIC_SUPABASE_ANON_KEY      = var.supabase_anon_key
    SUPABASE_SERVICE_ROLE_KEY     = var.supabase_service_role_key
  }
}
