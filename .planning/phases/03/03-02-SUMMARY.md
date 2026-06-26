---
phase: 03-integration-saas-vtc
plan: "02"
subsystem: terraform-infrastructure
tags: [terraform, supabase, cloudflare-pages, ci-cd, iac]
status: checkpoint-pending
checkpoint_task: "Task 6 — dry-run terraform plan"
dependency_graph:
  requires: [03-01]
  provides: [tfvars-non-sensibles, ci-supabase-secrets, task6-dry-run-pending]
  affects:
    - terraform/main.tf
    - terraform/variables.tf
    - terraform/terraform.tfvars
    - .github/workflows/plan.yml
    - .github/workflows/apply.yml
tech_stack:
  added: []
  patterns:
    - "terraform.tfvars tracke localement uniquement (gitignored par securite) — valeur exposee via default en variables.tf"
    - "TF_VAR_supabase_* mappes sur SUPABASE_ACCESS_TOKEN / SUPABASE_ORG_ID / SUPABASE_DB_PASSWORD dans plan.yml + apply.yml"
key_files:
  created:
    - terraform/terraform.tfvars (local uniquement — gitignored)
  modified:
    - terraform/variables.tf
    - terraform/main.tf
    - .github/workflows/plan.yml
    - .github/workflows/apply.yml
decisions:
  - "terraform.tfvars laisse gitignored (securite) — supabase_region a un default dans variables.tf, le CI n'a pas besoin du fichier"
  - "Noms de variables CI alignes sur variables.tf reels (supabase_organization_id, supabase_database_password) et non ceux du plan (supabase_org_id, db_password)"
metrics:
  duration: "7min"
  completed: "2026-06-26"
  tasks_completed: 2
  tasks_total: 3
  files_modified: 5
---

# Phase 3 Plan 02 : Cablage racine + CI — CHECKPOINT (Task 6 en attente)

tfvars non-sensibles + 3 secrets Supabase injectes dans les workflows CI ; Task 4 (cablage main.tf) validee depuis 03-01 ; dry-run `terraform plan` a valider par l'operateur.

## Taches Executees

| # | Nom | Commit | Fichiers cles |
|---|-----|--------|---------------|
| 4 | Cabler main.tf + outputs.tf racine | (03-01: `497c06e`) | `terraform/main.tf`, `terraform/outputs.tf` |
| 5 | tfvars non-sensibles + secrets CI | `b0c784a` | `terraform/terraform.tfvars`, `variables.tf`, `plan.yml`, `apply.yml` |
| 6 | Dry-run terraform plan | — | CHECKPOINT — validation humaine requise |

## Ce qui a ete construit

### Task 4 — Deja realisee par 03-01

Le worktree a ete synchronise avec `docs/03-supabase-integration` (fast-forward merge) pour recuperer les commits `c2a1a56`, `3da0d71`, `497c06e`. Toutes les acceptance criteria de Task 4 sont satisfaites :
- `module "supabase_project"` instancie dans `main.tf` avec `project_name = "${var.project_name}-${terraform.workspace}"`
- `env_vars = { DATABASE_URL = module.supabase_project.database_url, ... }` injecte dans `module.cloudflare_pages`
- `custom_domain = lookup(var.environment_domains, terraform.workspace, "")` present
- `outputs.tf` expose `supabase_database_url` (sensitive=true), `supabase_project_ref` + 3 outputs existants conserves
- Commentaire `# Test CI` supprime

### Task 5 — tfvars + CI

- `terraform/variables.tf` : variable `supabase_region` ajoutee (default `"eu-west-3"`)
- `terraform/main.tf` : `region = var.supabase_region` passe au module `supabase_project`
- `terraform/terraform.tfvars` : `supabase_region = "eu-west-3"` (fichier local, gitignored)
- `plan.yml` + `apply.yml` : 3 lignes TF_VAR_supabase_* ajoutees de facon coherente :
  ```yaml
  TF_VAR_supabase_access_token: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
  TF_VAR_supabase_organization_id: ${{ secrets.SUPABASE_ORG_ID }}
  TF_VAR_supabase_database_password: ${{ secrets.SUPABASE_DB_PASSWORD }}
  ```

### Task 6 — En attente (checkpoint:human-verify)

Le dry-run `terraform plan` requiert Terraform installe localement. Instructions dans la section Checkpoint ci-dessous.

## Deviations from Plan

### Auto-fixes (Rule 3 — bloquants)

**1. [Rule 3 - Blocking] Variable supabase_region absente de variables.tf racine**
- **Trouve pendant :** Task 5
- **Probleme :** Le plan demande `supabase_region = "eu-west-3"` dans tfvars, mais variables.tf racine ne declarait pas `supabase_region`. Terraform aurait rejete la valeur tfvars avec "Value for undeclared variable".
- **Fix :** Ajout de `variable "supabase_region"` dans variables.tf + passage `region = var.supabase_region` dans main.tf
- **Fichiers :** `terraform/variables.tf`, `terraform/main.tf`
- **Commit :** `b0c784a`

**2. [Rule 1 - Nommage] CI variables — noms reels vs noms du plan**
- **Probleme :** Le plan 03-02 utilisait `TF_VAR_supabase_org_id` et `TF_VAR_db_password`, mais les variables creees par 03-01 sont `supabase_organization_id` et `supabase_database_password`.
- **Fix :** Utilisation des vrais noms dans les workflows CI.
- **Impact :** Les noms de secrets GitHub Actions restent inchanges (SUPABASE_ORG_ID, SUPABASE_DB_PASSWORD) — seul le TF_VAR_* cote CI est aligne.

**3. [Decision] terraform.tfvars intentionnellement gitignored**
- `terraform/*.tfvars` est dans `.gitignore` (securite).
- `supabase_region` a `default = "eu-west-3"` dans variables.tf — le fichier tfvars est une aide locale, pas un pre-requis CI.
- Le fichier existe sur disque pour les runs locaux mais n'est pas tracke.

## User Setup Required — GitHub Secrets

Avant de merger, ajouter 3 secrets dans GitHub (Settings -> Secrets -> Actions) :

| Secret | Source |
|--------|--------|
| `SUPABASE_ACCESS_TOKEN` | Supabase Dashboard -> Account -> Access Tokens |
| `SUPABASE_ORG_ID` | Supabase Dashboard -> Organization Settings -> slug |
| `SUPABASE_DB_PASSWORD` | Mot de passe Postgres choisi (>= 12 caracteres) |

## Known Stubs

Aucun — plan infrastructure pure (Terraform HCL).

## Threat Flags

Aucun nouveau vecteur d'attaque introduit. Les mitigations T-03-01 (sensitive=true sur outputs), T-03-03 (backend R2) et T-03-06 (GitOps strict) restent inchangees.

## Self-Check: PASSED

- `b0c784a` present dans git log
- `supabase_region` present dans variables.tf
- `TF_VAR_supabase_access_token` present dans plan.yml et apply.yml
- Aucun secret keyword dans terraform.tfvars
