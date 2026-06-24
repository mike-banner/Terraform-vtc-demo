# Phase 2: Pipeline CI/CD & GitOps

## Goal
Automatiser le cycle de déploiement (GitOps) via GitHub Actions pour retirer toute intervention manuelle et garantir des déploiements sûrs.

## Steps

### 1. Workflow de Planification (Validation & Plan)
- Créer le fichier `.github/workflows/terraform-plan.yml`.
- Se déclenche sur les Pull Requests vers `main` ou `staging`.
- Étapes :
  - `terraform fmt -check` (Validation de la syntaxe).
  - `terraform init`.
  - `terraform validate`.
  - Sélection dynamique du Workspace en fonction de la branche cible.
  - `terraform plan` (Enregistrement du plan en commentaire de la PR).
- *Note : Ajouter des commentaires YAML pour expliquer l'objectif pédagogique de chaque step.*

### 2. Workflow de Déploiement (Apply Protégé)
- Créer le fichier `.github/workflows/terraform-apply.yml`.
- Se déclenche lors du `push` (merge) sur les branches `main` (Prod) ou `staging` (Staging).
- Étapes :
  - `terraform init`.
  - Sélection du Workspace cible.
  - `terraform apply -auto-approve`.
- *Note : Ajout des instructions pédagogiques expliquant que le merge sur main vaut validation d'architecture.*

## Verification
- Tester la validité YAML des actions avec un linter local si possible.
- Vérifier que les dépendances aux secrets (`CLOUDFLARE_API_TOKEN`) sont explicitement documentées.
