# Realtime Architecture — VTC HUB

## Synchro temps-réel (Astro + Supabase Channels)

### 🚗 Suivi des courses
- Abonnements aux changements de la table `bookings` pour rafraîchir l'écran Command Center du chauffeur.
- Utilisation de Supabase Realtime avec filtre sur `current_tenant_id()`.

### ⚡ Limitations actuelles (V1)
- L'état de la mission est synchronisé via des requêtes API standard (HTTP POST `/api/missions/terrain-transition`).
- La synchro en temps réel est utilisée en lecture seule pour la mise à jour fluide de l'UI (statut de la course sur la carte).
