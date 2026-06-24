# backend.tf
# Configure le stockage de l'état Terraform (tfstate).
#
# Choix : backend S3-compatible (Cloudflare R2).
# Cloudflare R2 expose une API S3 identique, ce qui évite de payer les frais
# d'egress d'AWS S3 tout en restant dans l'écosystème Cloudflare.
#
# Les Workspaces Terraform sont nativement supportés par le backend S3 :
# chaque workspace crée un fichier d'état séparé sous le préfixe "env:/<workspace>/".
#
# PRÉREQUIS : créer un bucket R2 nommé "vtc-tfstate" dans le dashboard Cloudflare,
# puis générer une paire de clés API R2 et les stocker dans GitHub Secrets :
#   CF_R2_ACCESS_KEY_ID / CF_R2_SECRET_ACCESS_KEY
#
# Pour un test local sans R2 : remplacer ce bloc par `backend "local" {}`
# et relancer `terraform init -migrate-state`.

terraform {
  backend "s3" {
    # Endpoint R2 : https://<account_id>.r2.cloudflarestorage.com
    # À renseigner via -backend-config ou TF_CLI_ARGS_init en CI.
    bucket = "vtc-tfstate"
    key    = "terraform.tfstate"
    region = "auto" # Cloudflare R2 utilise "auto" comme région fictive

    # Forcer le style de path S3 (R2 ne supporte pas le style virtual-hosted)
    force_path_style = true

    # Désactiver les checksums DynamoDB (non disponible sur R2)
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_lockfile                = false
  }
}
