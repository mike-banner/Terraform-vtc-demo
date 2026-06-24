# Forbidden Actions — VTC HUB

⚠️ **LISTE NOIRE DE L'IA — NE JAMAIS EFFECTUER CES ACTIONS** ⚠️

- **No client-side billing logic** : Interdiction de calculer les montants (`total_amount`, `minimum_fare`) en Javascript côté client.
- **No bypass of Row Level Security (RLS)** : Interdiction d'utiliser le client admin Supabase (`createAdminClient`) en dehors d'une API route sécurisée côté serveur.
- **No mutations on financial_movements** : Ne jamais tenter de modifier (`UPDATE`) ou de supprimer (`DELETE`) des lignes dans la table `financial_movements`. C'est un audit trail immuable.
- **No direct status manipulation** : Ne jamais changer le statut opérationnel d'un booking directement dans l'UI sans passer par la route API `/api/missions/terrain-transition`.
- **No non-responsive styles** : Interdiction d'ajouter des divs ou éléments à largeur fixe (`w-[1200px]`, etc.) sans implémenter la vue mobile responsive correspondante.
