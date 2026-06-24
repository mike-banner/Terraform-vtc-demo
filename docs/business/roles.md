# Roles & Permissions — VTC HUB

## Couche Platform

| Rôle | Accès |
|---|---|
| `super_admin` | Tout : onboardings, tenants, admin global |
| `platform_staff` | Onboardings uniquement |

**Stored in:** `profiles.platform_role`  
**Route:** `/admin/*`  
**Guard middleware :** `platform_role != NULL`

## Couche Tenant

| Rôle | Accès |
|---|---|
| `owner` | Dashboard complet : bookings, drivers, vehicles, finance, settings |
| `manager` | Sous-ensemble owner (V2 — pas encore implémenté) |
| `driver` | Vue terrain missions uniquement (V2 — pas encore implémenté) |

**Stored in:** `profiles.tenant_role`  
**Route:** `/app/*`  
**Guard middleware :** `tenant_id != NULL`

## Lifecycle Activation

```
Signup → profiles.tenant_role = 'pending'
→ Middleware bloque → /onboarding
→ Admin valide → approve_onboarding_tx()
→ profiles.tenant_role = 'owner'
→ profiles.tenant_id = <new_tenant_uuid>
→ Accès /app/dashboard
```

## Règles RLS Supabase

- Toute table métier filtrée par `current_tenant_id()`.
- `platform_role` = accès via service role dans Edge Functions uniquement.
- Jamais de donnée cross-tenant visible via anon key ou SSR standard.
- **INSERT `drivers`** : restreint aux `tenant_role = 'owner'` uniquement (policy `drivers_insert_owner_only`). Un `driver` collaborateur ne peut pas créer d'autres chauffeurs.
- **INSERT `financial_movements`** : restreint au `service_role` uniquement (immuabilité comptable).
