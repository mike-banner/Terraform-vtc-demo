# Naming Conventions — VTC HUB

## Base de Données (Postgres)
- Tables : `snake_case` (ex: `pricing_rules`, `financial_movements`).
- Colonnes : `snake_case` (ex: `tenant_id`, `stripe_payment_intent_id`).
- Triggers : `trg_[action_description]` (ex: `trg_single_active_vehicle`).

## Backend (Astro API / Deno Edge Functions)
- Routes API : Dossiers minuscules, fichiers en `kebab-case` ou `snake_case` (ex: `/api/missions/terrain-transition.ts`).
- Edge Functions : Nom de dossier en `kebab-case` (ex: `stripe_webhook/`).

## Frontend (React & Components)
- Composants React : `PascalCase` (ex: `BookingCard.tsx`, `ConfirmModal.tsx`).
- Pages Astro : `index.astro` ou routes dynamiques en minuscules (ex: `/app/dashboard/index.astro`).
