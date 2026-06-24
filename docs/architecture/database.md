# Database Architecture — VTC HUB

## Schéma Relationnel Multi-Tenant

```
[tenants] (id)
   ├── [profiles] (tenant_id)
   ├── [drivers] (tenant_id)
   ├── [vehicles] (tenant_id)
   ├── [pricing_rules] (tenant_id)
   └── [bookings] (current_tenant_id) ──> [financial_movements]
```

## RLS (Row Level Security)

Chaque table métier possède la policy de base suivante :
```sql
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON table_name
  USING (tenant_id = current_tenant_id());
```

Certaines tables ont des policies additionnelles par opération :

| Table | Policy spécifique | Condition |
|---|---|---|
| `drivers` | `drivers_insert_owner_only` (INSERT) | `tenant_role = 'owner'` requis |
| `financial_movements` | `finance_insert_service_only` (INSERT) | `service_role` uniquement |

## Triggers Métier Actifs

| Trigger | Table | Événement | Rôle |
|---|---|---|---|
| `trg_single_active_vehicle` | `vehicles` | BEFORE UPDATE/INSERT | Un seul véhicule actif par chauffeur |
| `trg_auto_financial_movement` | `bookings` | AFTER INSERT/UPDATE | Alimente `financial_movements` automatiquement (Stripe → `status=paid`, Cash → `mission_status=completed`) |
| `trg_sync_tenant_vat` | `tenants` | AFTER UPDATE | Synchronise `is_vat_exempt` + `vat_rate` selon `legal_form` |
| `trg_set_tenant_vat_on_insert` | `tenants` | AFTER INSERT | Initialise TVA à la création du tenant selon `legal_form` |

## Table Clé : `financial_movements` (Audit Trail)
- **Immuable** : Pas d'UPDATE ni de DELETE possible via trigger SQL.
- Trace tous les crédits/débits associés aux paiements et commissions Stripe.

## Pipeline TVA

Les prix de la grille tarifaire sont traités comme **TTC**. La TVA est extraite du TTC via :
```
HT = TTC / (1 + taux)
TVA = TTC - HT
```

Helper : `computeVat(totalTTC, vatRate)` dans `src/lib/pricing.ts`.

Règle de forme juridique (enforced par trigger) :
- `auto_entrepreneur`, `ei` → `is_vat_exempt = true`, `vat_rate = null`
- `sasu`, `sas`, `eurl`, `sarl`, `other` → `is_vat_exempt = false`, `vat_rate = 0.10`

## Vues SQL de Reporting & Fiscalité
Toutes les vues respectent la RLS (filtrage par tenant).

- **`financial_monthly_summary`** : Résumé mensuel par tenant (`gross_revenue` [TTC], `net_revenue` [HT], `vat_total`, `commission_total`, `refund_total`). Utilisé pour la déclaration de TVA.
- **`financial_yearly_summary`** : Résumé annuel pour le bilan comptable.
- **`financial_fiscal_detail`** : Vue granulaire de chaque mouvement financier pour export comptable.
