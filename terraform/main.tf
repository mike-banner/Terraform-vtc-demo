# main.tf
# Point d'entrée du module racine. Appelle le module cloudflare_pages
# en lui passant un nom de projet suffixé par le workspace actif.
#
# Exemple :
#   terraform workspace select dev  → project_name = "vtc-demo-dev"
#   terraform workspace select production → project_name = "vtc-demo-production"

module "cloudflare_pages" {
  source = "./modules/cloudflare_pages"

  account_id       = var.cloudflare_account_id
  project_name     = "${var.project_name}-${terraform.workspace}"
  github_owner     = var.github_owner
  github_repo_name = var.github_repo_name
}

# Test CI