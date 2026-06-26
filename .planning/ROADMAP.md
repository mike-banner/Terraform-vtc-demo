# Roadmap

## Progress

| Phase | Plan | Status | Summary |
|-------|------|--------|---------|
| 01 - Terraform Foundation & Workspaces | 1/1 | Complete   | 2026-06-25 |
| 02 - Pipeline CI/CD & GitOps | 1/1 | Complete   | 2026-06-26 |
| 03 - Intégration SaaS VTC | 2/2 | Complete   | 2026-06-26 |

## Phase 1: Terraform Foundation & Workspaces ✓

- [x] Configuration du backend distant (Remote State) — backend S3 Cloudflare R2
- [x] Définition du provider Cloudflare (~> 5.0)
- [x] Module générique cloudflare_pages (project + domaine conditionnel)
- [x] Structure racine : variables, outputs, main.tf avec workspace-suffix
- [ ] Workspaces Terraform créés (`dev`, `staging`, `production`) — **manuel requis** (voir SUMMARY)

## Phase 2: Pipeline CI/CD & GitOps

**Goal:** Automatiser le cycle de déploiement (GitOps) via GitHub Actions pour retirer toute intervention manuelle et garantir des déploiements sûrs.

**Plans:** 1/1 plans complete

Plans:
- [x] 02-01-PLAN.md — Workflows plan.yml (PR) + apply.yml (merge) + doc secrets/prérequis

- Création du workflow de Pull Request (`plan.yml`).
- Création du workflow de Merge (`apply.yml`).
- Sécurisation du pipeline (Variables d'environnement et secrets).

## Phase 3: Intégration du SaaS VTC (Cloudflare + Supabase)

**Goal:** Utiliser le socle workspace de la Phase 1 pour déployer le SaaS VTC multi-environnement : un projet Supabase par workspace dont l'URL de connexion est injectée automatiquement et de façon sécurisée dans les env_vars du projet Cloudflare Pages correspondant.

**Plans:** 2/2 plans complete

Plans:
- [ ] 03-PLAN.md — Provider + module Supabase, env_vars Cloudflare (secret_text), câblage main.tf (lien magique), domain_map, secrets CI, dry-run plan

- Définition du Provider Terraform Supabase.
- Création des projets de BDD Supabase isolés par Workspace (Dev/Staging/Prod).
- Liaison du dépôt source de l'application VTC avec les modules Terraform Cloudflare.
- Injection automatique des clés API et URLs Supabase dans les variables d'environnement Cloudflare Pages.
- Déploiement multi-environnement automatisé.
- Validation des accès Dashboard et Backoffice.
