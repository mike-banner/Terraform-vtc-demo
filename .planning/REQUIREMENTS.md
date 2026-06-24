# Requirements

## Validated

*(None yet — deploy to validate)*

## Active

- [ ] **IaC Foundation** : Code Terraform factorisé (DRY) et structuré.
- [ ] **Workspaces Terraform** : Création et gestion des espaces `dev`, `staging`, et `production`.
- [ ] **Remote State Management** : Configuration d'un backend distant sécurisé pour Terraform.
- [ ] **CI/CD Pipeline (Validation & Plan)** : Workflow GitHub Action qui exécute `terraform fmt`, `validate` et `plan` automatiquement à l'ouverture d'une Pull Request.
- [ ] **CI/CD Pipeline (Apply Protégé)** : Workflow GitHub Action qui exécute `terraform apply` post-merge, uniquement si les checks de la PR sont au vert.
- [ ] **Déploiement SaaS VTC** : Injection du code applicatif (SaaS VTC, Dashboard, Backoffice) dans l'infrastructure Cloudflare générée.

## Out of Scope

- [ ] Redéveloppement profond du code métier du SaaS VTC (Le focus est sur l'Infrastructure).
