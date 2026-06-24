# providers.tf
# Déclare le provider Cloudflare officiel.
# On fixe une version minimale (~> 5.0) pour éviter les breaking changes
# lors d'un `terraform init` futur. Le provider sera téléchargé depuis le
# registre Terraform public (registry.terraform.io).

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Configuration du provider Cloudflare.
# Le token API est injecté via la variable cloudflare_api_token (voir variables.tf)
# afin de ne jamais stocker de secret en clair dans le code source.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
