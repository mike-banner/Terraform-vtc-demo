# Business Overview — VTC HUB

## Positionnement

**ERP SaaS** pour chauffeurs VTC indépendants. Pas une marketplace.  
Chaque chauffeur = 1 tenant. Ses clients. Son Stripe. Son pricing.

## Modèle Multi-Tenant

```
Platform (VTC HUB)
└── Tenant A (Chauffeur / Société VTC)
    ├── drivers[]
    ├── vehicles[]
    ├── bookings[]
    ├── pricing_rules[]
    └── stripe_account_id
```

## Utilisateurs

| Rôle | Accès | Route |
|---|---|---|
| `super_admin` / `platform_staff` | Gestion plateforme, validation onboardings | `/admin/*` |
| `owner` | Dashboard ERP complet, réservations, finances | `/app/*` |
| `manager` | Sous-ensemble owner (prévu V2) | `/app/*` |
| `driver` | Vue terrain missions (prévu V2) | `/app/*` |

## Activation d'un nouveau tenant

```
Signup → onboarding (staging) → Validation manuelle admin → approve_onboarding_tx()
→ tenants + drivers + vehicles + pricing_rules créés atomiquement
```

**Règle :** jamais créer un tenant en dehors de `approve_onboarding_tx()`.

## Pricing Engine

```
total = base_price + (price_per_km × distance_km)
Si total < minimum_fare → total = minimum_fare
manual_total → override complet (bookings manuels uniquement)
```

Le calcul se fait toujours **backend**. Le frontend est estimation uniquement.
