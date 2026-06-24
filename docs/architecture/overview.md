# Architecture Overview — VTC HUB

## Logique Globale

```
[ Client (Astro WebApp) ] ──(HTTPS)──> [ Astro SSR Server (Cloudflare Pages) ]
                                                   │
                            ┌──────────────────────┴──────────────────────┐
                            ▼                                             ▼
                 [ Supabase API (Client) ]                     [ Supabase DB (Service Role) ]
                 - Auth checks                                 - RPC transactionnelles
                 - RLS (tenant isolation)                      - Stripe Webhooks
```

## Choix Structuels
- **Multi-tenant :** Séparation étanche par `tenant_id` sur chaque table.
- **Transactions :** Opérations complexes via RPC SQL pour éviter les désynchronisations.
- **Paiements :** Stripe Connect Express (chaque tenant encaisse directement).
