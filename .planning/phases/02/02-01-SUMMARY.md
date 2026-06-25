---
phase: 02-cicd-gitops
plan: "01"
subsystem: cicd

tags: [github-actions, terraform, gitops, cloudflare-r2, workflows]

requires:
  - "01-PLAN: backend.tf + variables.tf (bucket/key/region, TF_VAR_* mapping)"

provides:
  - "Workflow plan.yml : fmt+init+validate+plan commenté sur PR vers main/staging"
  - "Workflow apply.yml : init+apply -auto-approve sur push vers main/staging"
  - "README.md : 7 secrets, mapping workspace, prérequis bucket R2 et workspaces"

affects:
  - "Phase 3 : paths filter terraform/** peut nécessiter un ajout si nouveaux dossiers"

tech-stack:
  added:
    - actions/checkout@v4
    - hashicorp/setup-terraform@v4 (terraform_wrapper:true par défaut)
    - actions/github-script@v7
  patterns:
    - "TF_WORKSPACE env var pour sélection workspace avant init (pas de workspace select explicite)"
    - "-backend-config=endpoint=... pour injection endpoint R2 absent de backend.tf"
    - "continue-on-error + step exit 1 final pour propager l'échec du plan après commentaire PR"
    - "permissions pull-requests:write uniquement sur plan.yml (github-script)"

key-files:
  created:
    - .github/workflows/plan.yml
    - .github/workflows/apply.yml
    - .github/workflows/README.md

key-decisions:
  - "TF_WORKSPACE via env job plutôt que terraform workspace select explicite (plus simple, officiel)"
  - "github.base_ref dans plan.yml (PR), github.ref_name dans apply.yml (push) — distinction critique"
  - "continue-on-error sur fmt et plan avec step exit 1 final (piège 3 documenté en research)"
  - "createComment simple plutôt que update-existing-comment (YAGNI, piège résolu si gênant)"

metrics:
  duration: "12min"
  completed: "2026-06-25"
  tasks_completed: 3
  tasks_total: 4
  files_created: 3
  files_modified: 0
---

# Phase 02 Plan 01 : Workflows GitHub Actions CI/CD Summary

**Deux workflows GitOps (plan sur PR, apply sur merge) + README des 7 secrets, avec sélection dynamique du workspace via TF_WORKSPACE et injection endpoint R2 via -backend-config**

## Performance

- **Duration:** 12 min
- **Completed:** 2026-06-25
- **Tasks:** 3/4 (arrêt au checkpoint humain — task 4)
- **Files created:** 3

## Accomplishments

- `plan.yml` : PR vers main/staging déclenche fmt-check, init (avec endpoint R2 injecté), validate, plan ; commentaire PR avec statut et détail du plan dans un bloc `<details>` ; échec du plan propagé via step `exit 1` après le commentaire
- `apply.yml` : push/merge vers main/staging déclenche init + apply -auto-approve ; workspace sélectionné via `github.ref_name` ; permissions limitées à `contents:read`
- `README.md` : table des 7 secrets avec source dashboard, mapping branche→workspace, prérequis bucket R2 et création workspaces, note branch protection rule

## Task Commits

| Task | Description | Commit |
|---|---|---|
| 1 | Workflow Terraform Plan (PR) | `2ec7ca4` |
| 2 | Workflow Terraform Apply (merge) | `a1aa262` |
| 3 | README secrets, mapping, prérequis | `99cb714` |
| 4 | Checkpoint humain (en attente) | — |

## Deviations from Plan

Aucune — plan exécuté exactement comme spécifié.

Les pièges documentés dans la research ont tous été adressés :
- Piège 3 (continue-on-error sans exit 1) : step `Fail if plan failed` présent
- Piège 4 (pull-requests:write manquant) : permission déclarée au niveau workflow dans plan.yml
- Piège 2 (paths filter manquant) : `paths: ['terraform/**']` présent sur les deux workflows

## Threat Surface Scan

| Flag | Fichier | Description |
|---|---|---|
| T-02-01 mitigé | plan.yml | Variables TF_VAR_cloudflare_api_token marquées sensitive dans variables.tf ; GitHub Actions masque automatiquement les secrets dans les logs |
| T-02-02 mitigé | README.md | Branch protection rule documentée comme prérequis bloquant (section 4) |
| T-02-04 mitigé | plan.yml, apply.yml | paths: ['terraform/**'] présent sur les deux workflows |

Aucun nouveau threat non couvert par le plan n'a été identifié.

## Self-Check: PASSED

- [x] `.github/workflows/plan.yml` existe et YAML valide
- [x] `.github/workflows/apply.yml` existe et YAML valide
- [x] `.github/workflows/README.md` existe avec 7 secrets documentés
- [x] Commit `2ec7ca4` : plan.yml
- [x] Commit `a1aa262` : apply.yml
- [x] Commit `99cb714` : README.md
- [x] Aucun credential hardcodé (grep vérifié)
- [x] base_ref dans plan.yml, ref_name dans apply.yml (jamais l'inverse)
