# Architecture Backend — VTC HUB

## Stack Backend

| Composant | Techno | Rôle |
|---|---|---|
| Serveur | Astro SSR (`output: "server"`) | API Routes + SSR Pages |
| Database | Supabase Postgres | Source de vérité données |
| Auth | Supabase Auth | Session + JWT |
| Edge | Supabase Edge Functions (Deno) | Webhooks Stripe |
| Infra | Cloudflare Pages + Workers | Déploiement + CDN |

## 3 Clients Supabase

```typescript
// 1. Browser — anon key — RLS enforced
// src/lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr'

// 2. SSR — cookies — RLS enforced
// src/middleware.ts → locals.supabase
import { createServerClient } from '@supabase/ssr'

// 3. Admin — service role — RLS BYPASSED
// src/lib/supabase/server.ts
export const createAdminClient = () => createClient(url, SERVICE_ROLE_KEY)
// ⚠️ UNIQUEMENT dans les API Routes côté serveur
```

## API Routes Structure

```
src/pages/api/
├── missions/
│   └── terrain-transition.ts  ← Transitions opérationnelles terrain
├── bookings/
│   ├── create.ts
│   └── cancel.ts
├── payments/
│   └── create-checkout.ts
└── admin/
    └── approve-onboarding.ts
```

## Middleware Auth Flow

```typescript
// src/middleware.ts
// 1. Crée locals.supabase (SSR client par requête)
// 2. Récupère session
// 3. Récupère profile (platform_role, tenant_role, tenant_id)
// 4. Redirections :
//    - Non connecté → /login
//    - platform_role → /admin
//    - tenant_id actif → /app/dashboard
//    - pending → /onboarding
```

## Edge Functions (Deno)

```
supabase/functions/
├── accept-booking/     → Assigne chauffeur à une réservation
├── send-email/         → Proxy d'envoi d'emails via Resend
└── stripe_webhook/     → Traite checkout.session.completed + charge.refunded
```

### Sécurité Stripe Webhook

1. Vérification signature `Stripe-Signature` header
2. Check idempotence dans `stripe_events`
3. Traitement → INSERT `financial_movements`
4. Marquer `stripe_events.processed = true`

## Base de Données — Tables Clés

| Table | Rôle |
|---|---|
| `tenants` | Entité entreprise SaaS |
| `profiles` | Lien auth.users → tenant |
| `onboarding` | Staging avant activation |
| `drivers` | Chauffeurs par tenant |
| `vehicles` | Véhicules par tenant |
| `bookings` | Réservations (core business) |
| `pricing_rules` | Tarification par tenant |
| `cancellation_policies` | Règles remboursement versionnées |
| `financial_movements` | **Audit trail immuable** |
| `stripe_events` | Idempotence Stripe |
| `commissions` | Commissions V2 (dormant) |

## RPC SQL Critiques

```sql
-- Activation tenant (transaction atomique)
SELECT approve_onboarding_tx('uuid');

-- Suppression de compte (Danger Zone)
-- Désactive profil, marque tenant deleted_at, anonymise les données sensibles
SELECT delete_tenant_account('tenant_uuid');

-- Contexte tenant courant (utilisé dans RLS)
SELECT current_tenant_id();

-- Réactiver triggers si désactivés en dev
ALTER TABLE bookings ENABLE TRIGGER ALL;
```

## Vues de Reporting

```sql
tenant_dashboard_kpi            -- KPIs dashboard
financial_movements             -- Ledger complet
financial_monthly_summary       -- Agrégation mensuelle
financial_yearly_summary        -- Agrégation annuelle
financial_fiscal_detail         -- Export TVA / audit
tenant_accounting_ledger        -- ⚠️ Nécessite cast `as any` si types désync
```

## Migrations

```
supabase/migrations/          ← Source de vérité absolue du schéma
```

Jamais modifier le schéma en dehors d'une migration SQL.  
Après migration : `npm run gen:types` pour régénérer les types TS.

## Variables d'Environnement

```bash
PUBLIC_SUPABASE_URL=           # Client browser
PUBLIC_SUPABASE_ANON_KEY=      # Client browser (safe à exposer)
SUPABASE_SERVICE_ROLE_KEY=     # Server uniquement — JAMAIS dans browser

# Stripe → secrets Edge Functions Supabase (pas dans .env local)
```
