---
phase: 03-supabase-integration
plan: "01"
subsystem: terraform-infrastructure
tags: [terraform, supabase, cloudflare-pages, iac, workspaces]
dependency_graph:
  requires: [02-01]
  provides: [supabase-module, cloudflare-env-wiring, domain-map]
  affects: [terraform/main.tf, terraform/providers.tf, terraform/variables.tf, terraform/modules/supabase_project/]
tech_stack:
  added:
    - "supabase/supabase Terraform provider ~> 1.0"
  patterns:
    - "Module Terraform réutilisable supabase_project (identique au pattern cloudflare_pages)"
    - "Injection database_url via env_vars → deployment_configs.production.environment_variables"
    - "depends_on explicite supabase → cloudflare pour ordre de création garanti"
    - "lookup() sur environment_domains pour domaine custom par workspace"
key_files:
  created:
    - terraform/modules/supabase_project/main.tf
    - terraform/modules/supabase_project/variables.tf
    - terraform/modules/supabase_project/outputs.tf
  modified:
    - terraform/providers.tf
    - terraform/variables.tf
    - terraform/main.tf
    - terraform/modules/cloudflare_pages/variables.tf
    - terraform/modules/cloudflare_pages/main.tf
    - terraform/outputs.tf
decisions:
  - "supabase/supabase ~> 1.0 (provider officiel Terraform Registry)"
  - "database_url construite depuis project.id (ref) + password car le provider v1 n'expose pas d'attribut database_url natif"
  - "env_vars map(string) + secret_text pour all (contiennent des credentials)"
  - "deployment_configs null si env_vars vide (évite un bloc inutile sur les installs baseline)"
  - "depends_on explicite en plus du lien implicite via module output (défense en profondeur)"
  - "Dry-run terraform plan non exécuté — terraform non installé dans l'environnement agent (même contrainte que phase 01)"
metrics:
  duration: "5min"
  completed: "2026-06-26"
  tasks_completed: 3
  tasks_total: 4
  files_modified: 10
---

# Phase 3 Plan 01 : Intégration Supabase + câblage Cloudflare Pages

Provider Supabase ajouté, module `supabase_project` créé, et `database_url` injectée automatiquement dans les env_vars de Cloudflare Pages via `deployment_configs.production.environment_variables`.

## Tâches Exécutées

| # | Nom | Commit | Fichiers clés |
|---|-----|--------|---------------|
| 1 | Provider Supabase + variables | `c2a1a56` | `terraform/providers.tf`, `terraform/variables.tf` |
| 2 | Module supabase_project | `3da0d71` | `modules/supabase_project/{main,variables,outputs}.tf` |
| 3 | Câblage main.tf + env_vars CF | `497c06e` | `main.tf`, `modules/cloudflare_pages/{main,variables}.tf`, `outputs.tf` |
| 4 | Dry-run terraform plan | — | DÉFÉRÉ (terraform non installé) |

## Ce qui a été construit

### Task 1 — Provider Supabase + variables
- `providers.tf` : provider `supabase/supabase ~> 1.0` + bloc `provider "supabase"` avec access_token
- `variables.tf` : 4 nouvelles variables — `supabase_access_token` (sensitive), `supabase_organization_id`, `supabase_database_password` (sensitive), `environment_domains` (map workspace→domaine avec defaults)

### Task 2 — Module `modules/supabase_project/`
- `variables.tf` : project_name, organization_id, database_password (sensitive), region (default: eu-west-3)
- `main.tf` : `resource "supabase_project"` avec les 4 attributs requis
- `outputs.tf` : `database_url` (sensitive, construite depuis project.id + password), `api_url` (HTTPS), `project_ref`

### Task 3 — Câblage Supabase → Cloudflare Pages
- `main.tf` : instancie `module.supabase_project` + passe `database_url`/`api_url` en env_vars au module Cloudflare ; `custom_domain` résolu via `lookup(var.environment_domains, terraform.workspace, "")`
- `modules/cloudflare_pages/variables.tf` : ajoute `env_vars map(string) sensitive default {}`
- `modules/cloudflare_pages/main.tf` : `deployment_configs` avec `secret_text` pour production + preview si env_vars non vide ; null sinon
- `outputs.tf` : expose `supabase_project_ref`, `supabase_api_url`, `supabase_database_url` (sensitive)

## Deviations from Plan

### Déférés

**Step 5 — Dry-run terraform plan**
- **Raison :** terraform non installé dans l'environnement agent (contrainte identique à phase 01)
- **Action requise :** exécuter manuellement `terraform init` puis `terraform plan` avec les variables factices (voir section ci-dessous)

## User Setup Required

Pour valider l'arbre de dépendances localement :

```bash
cd terraform

# Init avec backend local pour le test
terraform init -backend-config="backend=local" 2>/dev/null || terraform init -migrate-state

# Workspace dev
terraform workspace select dev || terraform workspace new dev

# Plan avec variables factices (vérifie la syntaxe et les dépendances)
terraform plan \
  -var="cloudflare_api_token=fake-cf-token" \
  -var="cloudflare_account_id=fake-account-id" \
  -var="github_owner=fake-owner" \
  -var="github_repo_name=fake-repo" \
  -var="supabase_access_token=fake-sb-token" \
  -var="supabase_organization_id=fake-org-id" \
  -var="supabase_database_password=fake-password-123"
```

Attendu dans le plan :
- `module.supabase_project.supabase_project.this` — will be created
- `module.cloudflare_pages.cloudflare_pages_project.this` — will be created
- Supabase apparaît AVANT Cloudflare dans l'arbre de dépendances

## Known Stubs

Aucun stub IHM — ce plan est infrastructure pure (Terraform HCL).

## Threat Flags

| Flag | Fichier | Description |
|------|---------|-------------|
| threat_flag: sensitive-output | `terraform/outputs.tf` | `supabase_database_url` marked sensitive, mais visible via `terraform output -raw supabase_database_url` par quiconque a accès au tfstate R2 — cohérent avec T-02-01 (accepted) |

## Self-Check: PASSED

Tous les fichiers créés confirmés sur disque. Commits `c2a1a56`, `3da0d71`, `497c06e` présents dans l'historique git.
