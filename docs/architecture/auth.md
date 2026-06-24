# Authentication & Guards — VTC HUB

## Flux Auth & Onboarding

```
1. Inscription (Supabase Auth)
2. Insertion profil via trigger handle_new_user() -> tenant_role = 'pending'
3. Middleware force la redirection vers /onboarding
4. Remplissage SIRET + Licence VTC
5. Validation Super Admin -> approve_onboarding_tx()
6. tenant_role -> 'owner' + affectation tenant_id
7. Accès autorisé à /app/*
```

## Middleware Guards
Le middleware (`src/middleware.ts`) intercepte toutes les requêtes :
- `/admin/*` : Requiert `platform_role IS NOT NULL`.
- `/app/*` : Requiert `tenant_id IS NOT NULL`.
- `/onboarding` : Réservé aux profils en statut `pending`.
