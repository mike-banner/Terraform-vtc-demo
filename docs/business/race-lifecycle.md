# Race Lifecycle — VTC HUB

> Fichier critique. Toute modification du lifecycle booking/mission doit être validée ici d'abord.

## Statuts Booking (financial)

```
pending
  ↓ (chauffeur accepte)
accepted_pending_payment
  ↓ (Stripe webhook: checkout.session.completed)
paid
  ↓ (mission terminée)
completed

pending ou accepted_pending_payment
  ↓ (annulation)
cancelled_pending_refund
  ↓ (Stripe webhook: charge.refunded)
cancelled_refunded

cancelled_no_refund  (selon cancellation_policy)
```

## Statuts Mission (opérationnel terrain)

```
to_validate     → Booking créé, chauffeur pas encore confirmé
not_started     → Chauffeur assigné, mission pas commencée
in_progress     → Client à bord
completed       → Course terminée
```

**Règle absolue : jamais sauter d'étape. Toujours via `POST /api/missions/terrain-transition`.**

## Transitions Terrain

| Action bouton | Payload `action` | Passage mission_status |
|---|---|---|
| "Je suis en route" | `en_route` | → `not_started` |
| "Client à bord" | `on_board` | → `in_progress` |
| "Course terminée" | `completed` | → `completed` |

- Bouton "En route" : bloqué jusqu'à **H-15** avant pickup_time (garde temporelle).
- Logs horodatés dans `mission_note` : format `[terrain] action_at=ISO`.
- QR Code notation + Facture : débloqués uniquement si `mission_status = 'completed'`.

## Flow Création Booking (Backoffice)

```
1. Form frontend → distance_km envoyé
2. API Route → récupère pricing_rules actif
3. Recalcule total (backend)
4. Insère booking (status = 'pending')
5. Auto-assign driver si booking manuel (chauffeur créateur)
```

## Flow Paiement (Stripe)

```
1. Checkout session créée
2. Client paie
3. Stripe → webhook checkout.session.completed
4. Edge Function stripe_webhook:
   a. Vérifie signature
   b. Vérifie idempotence (stripe_events)
   c. booking.status → 'paid'
   d. financial_movements INSERT (type: payment, direction: credit)
   e. financial_movements INSERT (type: commission, direction: debit)
   f. stripe_events.processed = true
```

## Flow Annulation & Remboursement

```
1. Annulation initiée (client / driver / admin)
2. booking.status → 'cancelled_pending_refund'
3. Stripe API → refund initié
4. Stripe → webhook charge.refunded
5. Edge Function stripe_webhook:
   a. Calcul ratio = refund_amount / booking.total_amount
   b. financial_movements INSERT (type: refund, direction: debit, ratio)
   c. financial_movements INSERT (type: commission_reversal, direction: credit, ratio)
   d. booking.status → 'cancelled_refunded'
```

**Immuabilité :** jamais UPDATE un `financial_movements`. Toujours un mouvement inverse.

## Booking Manuel vs En Ligne

| Critère | Manuel | En ligne |
|---|---|---|
| Créateur | Owner/Manager backoffice | Client via site |
| Prix | `manual_total` autorisé | Calcul auto obligatoire |
| Assignment | Auto → chauffeur créateur | Dispatch ou manuel |
| Paiement | Cash / virement / Stripe | Stripe uniquement |

## Règle Véhicule Exclusif

Un seul véhicule actif par chauffeur à tout moment.  
L'activation d'un nouveau véhicule désactive automatiquement les autres (trigger DB).
