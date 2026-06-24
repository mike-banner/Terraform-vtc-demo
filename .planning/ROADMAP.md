# Roadmap

## Phase 1: Terraform Foundation & Workspaces
- Configuration du backend distant (Remote State).
- Définition du provider Cloudflare.
- Mise en place des Workspaces Terraform (`dev`, `staging`, `production`).
- Création du module générique (Cloudflare Pages).

## Phase 2: Pipeline CI/CD & GitOps
- Création du workflow de Pull Request (`plan.yml`).
- Création du workflow de Merge (`apply.yml`).
- Sécurisation du pipeline (Variables d'environnement et secrets).

## Phase 3: Intégration du SaaS VTC
- Liaison du dépôt source de l'application VTC avec les modules Terraform.
- Déploiement multi-environnement.
- Validation des accès Dashboard et Backoffice.
