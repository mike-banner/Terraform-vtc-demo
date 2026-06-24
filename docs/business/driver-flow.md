# Driver Flow — VTC HUB

## Cycle Opérationnel du Chauffeur (Mobile First)

```
Écran Dashboard (Mobile)
  ├── 1. Stat Grid (Aujourd'hui, Mois, Revenus)
  ├── 2. Active Mission Card (Focus immédiat)
  └── 3. Next Missions (Max 3 items)
```

## Actions terrain (Missions)

```
Mission assignée
  ↓
Bouton "En route" (Activable uniquement à H-15 min du pickup)
  ↓ [mission_status: not_started, mission_note logs: [terrain] action_at]
Bouton "Client à bord"
  ↓ [mission_status: in_progress, mission_note logs: [terrain] action_at]
Bouton "Course terminée"
  ↓ [mission_status: completed, mission_note logs: [terrain] action_at]
Restauration Facture & QR Code notation (Débloqués)
```

## Véhicule Unique
- Règle DB : Un seul véhicule marqué actif à la fois par chauffeur.
- L'activation d'un véhicule désactive automatiquement tous les autres.
