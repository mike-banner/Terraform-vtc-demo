# Coding Rules — VTC HUB

## Directives Générales

1. **Astro SSR (Server-Side First)** :
   - Préférer le rendu côté serveur.
   - Restreindre l'utilisation de React aux îlots interactifs (`client:load`).

2. **Mobile First Absolu** :
   - Tester toute UI sur un écran de 375px.
   - Ne jamais utiliser de breakpoints desktop (`lg:`) pour la structure par défaut.

3. **Validation Serveur** :
   - Le client ne doit jamais être la source de vérité pour les calculs d'argent ou les changements de statuts.
   - Toujours passer par des API routes `/api/*` ou des fonctions RPC de base de données.
