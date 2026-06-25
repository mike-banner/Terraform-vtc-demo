# Roadmap

## Progress

| Phase | Plan | Status | Summary |
|-------|------|--------|---------|
| 01 - Terraform Foundation & Workspaces | PLAN | COMPLETE | [01-PLAN-SUMMARY.md](phases/01/01-PLAN-SUMMARY.md) |
| 02 - Pipeline CI/CD & GitOps | PLAN | PENDING | - |
| 03 - Intégration SaaS VTC | PLAN | PENDING | - |

## Phase 1: Terraform Foundation & Workspaces ✓

- [x] Configuration du backend distant (Remote State) — backend S3 Cloudflare R2
- [x] Définition du provider Cloudflare (~> 5.0)
- [x] Module générique cloudflare_pages (project + domaine conditionnel)
- [x] Structure racine : variables, outputs, main.tf avec workspace-suffix
- [ ] Workspaces Terraform créés (`dev`, `staging`, `production`) — **manuel requis** (voir SUMMARY)

## Phase 2: Pipeline CI/CD & GitOps

- Création du workflow de Pull Request (`plan.yml`).
- Création du workflow de Merge (`apply.yml`).
- Sécurisation du pipeline (Variables d'environnement et secrets).

## Phase 3: Intégration du SaaS VTC

- Liaison du dépôt source de l'application VTC avec les modules Terraform.
- Déploiement multi-environnement.
- Validation des accès Dashboard et Backoffice.
