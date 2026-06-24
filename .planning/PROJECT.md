# VTC SaaS Infrastructure (Terraform & GitOps)

## Vision & What This Is
Le projet déploie une infrastructure de classe entreprise (Infrastructure as Code) pour héberger en production une application SaaS B2B fonctionnelle (Dashboard et Backoffice pour chauffeurs VTC).
L'objectif central est d'implémenter une gestion d'environnements scalable via Terraform Workspaces, et l'application stricte des pratiques GitOps (CI/CD automatisée).

## Architecture & Tech Stack
- **Application** : SaaS VTC (Frontend Astro/Nuxt, Backend/DB Supabase/Cloudflare).
- **Infrastructure as Code** : Terraform (Workspaces : `dev`, `staging`, `production`).
- **Cloud Provider** : Cloudflare (Pages, potentiellement Workers/D1 selon le besoin SaaS).
- **CI/CD & GitOps** : GitHub Actions (Plans automatiques sur Pull Request, Apply sécurisé sur Merge).

## Key Decisions
| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Utilisation de Terraform Workspaces | Plus élégant et "Enterprise-ready" que la duplication de dossiers pour dev/staging/prod | Standardisation de l'IaC |
| GitOps via GitHub Actions | Standardisation du Release Management et validation rigoureuse des déploiements | CI/CD automatisée et sécurisée |

---
*Last updated: 2026-06-25 après initialisation GSD*
