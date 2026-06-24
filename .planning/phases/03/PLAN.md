# Phase 3: Intégration du SaaS VTC

## Goal
Utiliser le socle créé lors de la Phase 1 pour déployer concrètement le SaaS VTC (Dashboard et Backoffice) sur les différents environnements.

## Steps

### 1. Instanciation du Module Principal
- Créer `terraform/main.tf` qui va appeler le module `cloudflare_pages`.
- Utiliser la variable magique `terraform.workspace` pour adapter dynamiquement la configuration.
- Exemple d'intégration :
  ```hcl
  locals {
    env = terraform.workspace
    project_name = "vtc-saas-${local.env}"
  }
  ```

### 2. Adaptation des Domaines par Workspace
- Configurer un dictionnaire (map) dans les variables pour lier l'environnement à son nom de domaine:
  - `dev` -> `dev.vtc-saas.com`
  - `staging` -> `staging.vtc-saas.com`
  - `production` -> `app.vtc-saas.com`

### 3. Exécution d'un Plan à blanc (Dry-Run)
- Faire un `terraform plan` sur le workspace `dev` avec des variables factices pour valider l'arbre de dépendances des ressources créées.

## Verification
- Le `terraform plan` final doit montrer la création distincte d'un projet Cloudflare Pages spécifique à l'environnement.
- Aucun secret métier ne doit fuiter dans le code en dur.
