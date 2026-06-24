# Frontend Architecture — VTC HUB

## Stack UI

- **Astro** (SSR) : Rendu dynamique, routing et gestion des sessions.
- **React Islands** (`client:load`) : Pour les widgets interactifs (Dashboard, Calendrier, Cartes).
- **TailwindCSS** : Utilitaire CSS standard pour le responsive.

## Directives Mobile-First

- Toute page doit être testée à la largeur 375px.
- Aucun composant ne doit déborder horizontalement.
- Target tactile minimum : 44x44px.
- La Navigation s'effectue via une Bottom Bar sur mobile (5 boutons max, adaptative selon les rôles).
- Modales et formulaires utilisent des overlays avec confirmation.

## Communication API
- Les actions UI s'appuient sur `/api/*` routes.
- Pas d'appels directs à la DB depuis le composant React browser sans passer par le client Supabase configuré avec RLS.

## Sécurité Session (Timeout)
- Composant : `src/components/common/InactivityTimeout.astro` (inclus dans `AppLayout` et `AdminLayout`).
- Délai d'inactivité : **30 minutes** (souris, clavier, tactile).
- Action : Déconnexion automatique et redirection vers `/login?reason=inactivity`.

## Design UI Guidelines
- Esthétique **Glassmorphism Dark** :
  - Overlays avec floutage : `backdrop-blur-sm`, `border-white/10`.
  - Animations de transitions d'échelle : `scale-95` -> `scale-100`.
  - Toggles : Switches couleur Indigo pour les statuts.
  - Cartes et Listes : Layout fluide avec coins arrondis et bordures translucides.

