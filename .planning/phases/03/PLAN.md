# Phase 3: Intégration du SaaS VTC (Cloudflare + Supabase)

## Goal
Utiliser le socle créé lors de la Phase 1 pour déployer concrètement le SaaS VTC sur les différents environnements. Cette phase intègre le Frontend (Cloudflare Pages) et la Base de Données (Supabase) via Terraform.

## Steps

### 1. Provider Supabase
- Ajouter le provider `supabase/supabase` dans le fichier `providers.tf`.
- Ajouter la variable sécurisée `supabase_access_token` dans `variables.tf`.

### 2. Module Supabase (Base de données)
- Créer un module Terraform `modules/supabase_project/main.tf`.
- Créer un projet Supabase automatiquement pour chaque environnement (`dev`, `staging`, `production`).
- Exporter l'URL de la base de données générée via `outputs.tf`.

### 3. Instanciation Principale (main.tf)
- Dans le fichier `terraform/main.tf` (racine), instancier le module Supabase.
- Instancier le module Cloudflare Pages.
- **Le lien magique :** Injecter l'URL retournée par le module Supabase directement dans les variables d'environnement (`env_vars`) du module Cloudflare Pages.

### 4. Adaptation des Domaines par Workspace
- Configurer un dictionnaire (map) dans les variables pour lier l'environnement à son nom de domaine:
  - `dev` -> `dev.vtc-saas.com`
  - `staging` -> `staging.vtc-saas.com`
  - `production` -> `app.vtc-saas.com`

### 5. Exécution d'un Plan à blanc (Dry-Run)
- Faire un `terraform plan` sur le workspace `dev` avec des variables factices pour valider l'arbre de dépendances (Supabase DOIT se créer avant Cloudflare).

## Verification
- Le `terraform plan` final doit montrer la création distincte d'un projet Cloudflare ET d'un projet Supabase.
- La variable `database_url` doit être correctement injectée dans Cloudflare sans fuiter dans le code brut.
