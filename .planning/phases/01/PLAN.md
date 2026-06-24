# Phase 1: Terraform Foundation & Workspaces

## Goal
Établir le socle d'Infrastructure as Code. Ce socle doit être modulaire, utiliser les Workspaces Terraform, et configurer le backend (Remote State) de manière sécurisée.

## Steps

### 1. Structure Racine et Providers
- Créer `terraform/providers.tf` pour configurer le provider `cloudflare/cloudflare`.
- *Note : Tous les blocs HCL générés devront contenir des commentaires pédagogiques en français expliquant le choix.*

### 2. Configuration du Backend (Remote State)
- Créer `terraform/backend.tf` pour configurer la gestion de l'état (utilisation d'un backend `s3` compatible Cloudflare R2 ou AWS, ou fallback sur `local` si contrainte de credentials, mais configuré pour supporter les workspaces).

### 3. Fichiers de Variables et Outputs
- Créer `terraform/variables.tf` (ex: `cloudflare_api_token`, `cloudflare_account_id`).
- Créer `terraform/outputs.tf` pour exporter les URLs générées.

### 4. Module Cloudflare Pages
- Créer le dossier `terraform/modules/cloudflare_pages`.
- Créer `modules/cloudflare_pages/main.tf` contenant les ressources `cloudflare_pages_project` et `cloudflare_pages_domain`.
- Créer `modules/cloudflare_pages/variables.tf`.

## Verification
- Lancer `terraform init` localement.
- Créer les workspaces: `terraform workspace new dev`, `staging`, et `production`.
- Vérifier avec `terraform validate` que la syntaxe et l'architecture modulaire sont correctes.
