# Critical Files Reference — VTC HUB

## Fichiers Cœur à lire en priorité

| Fichier | Description |
|---|---|
| `src/middleware.ts` | Guard de sécurité global, routage et validation de session |
| `src/lib/supabase/server.ts` | Client admin (`createAdminClient`) à manier avec précaution |
| `src/pages/api/missions/terrain-transition.ts` | Route gérant les boutons de transition chauffeur |
| `supabase/functions/stripe_webhook/index.ts` | Traitement des webhooks de paiement et de remboursement Stripe |
| `supabase/migrations/` | Définition des triggers (véhicule actif, immuabilité financière) |

## Zones d'interdiction (Ne pas modifier sans validation)
- Le modèle de table `financial_movements`.
- La logique RLS de sécurité.
- Le trigger d'onboarding Super Admin.
