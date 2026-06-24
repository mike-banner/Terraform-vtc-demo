# Rappels de fin de course — Options techniques

> Contexte : le chauffeur peut oublier de cliquer "Course terminée", ce qui fausse
> les timestamps `completed_at` dans le ledger. Ce document liste les approches
> disponibles, classées par complexité.

## Approche retenue (MVP)

**Bannière in-app + picker de confirmation** — implémenté dans `AppLayout.astro`.

- Bannière sticky au-dessus du bottom nav mobile, rétractable, visible sur toutes les pages `/app/*`
  quand une mission est en `in_progress`.
- Au clic "Course terminée" : si delta `now - started_at > 4h`, proposer un picker
  datetime pour corriger l'heure réelle avant insertion.
- Fallback ledger : si `completed_at` est absente mais `mission_status = completed`,
  utiliser `pickup_time` comme approximation dans les vues.

---

## Alternatives pour V2

### Option A — Push Notifications (Web Push API)

Envoie un rappel natif au chauffeur si une mission est en `in_progress` depuis plus de N heures,
même si l'app est fermée.

**Prérequis :**
- Service Worker (`/public/sw.js`)
- Clés VAPID (`web-push` npm, ou Supabase Edge Function)
- Table `push_subscriptions(tenant_id, driver_id, endpoint, keys_p256dh, keys_auth)`
- Cron Edge Function Supabase : `check_stuck_missions` toutes les 30 min
  - SELECT bookings WHERE mission_status = 'in_progress' AND started_at < now() - interval '4h'
  - Pour chaque → POST to push endpoint

**Coût :** 1-2 jours. Bloquant : permissions utilisateur (opt-in navigateur requis).

**Fichiers à créer :**
```
public/sw.js                                    ← Service Worker
supabase/functions/check-stuck-missions/        ← Cron Edge Function
src/lib/push.ts                                 ← Helpers subscription
```

### Option B — SMS via Twilio / Vonage

Envoie un SMS au numéro du chauffeur si la mission dépasse N heures.

**Prérequis :**
- Compte Twilio ou Vonage
- Numéro de téléphone sur le profil chauffeur (`drivers.phone`)
- Edge Function `send-sms` (pattern identique à `send-email`)
- Même logique cron que Option A

**Coût :** 1 jour + coût SMS (env. 0.07€/SMS).

### Option C — Alerte in-app améliorée (badge + son)

Étend la bannière MVP avec :
- Badge rouge sur l'icône de l'app (Web App Manifest `badge`)
- Son d'alerte discret via Web Audio API
- Vibration haptic (`navigator.vibrate([200, 100, 200])`) sur mobile

**Prérequis :** zéro infra supplémentaire, tout côté client.  
**Coût :** quelques heures.

---

## Décision de timestamp en cas d'oubli

Si `completed_at` est trop tardive (delta > 6h depuis `started_at`), le picker propose :
1. Confirmer l'heure actuelle
2. Saisir l'heure réelle de fin
3. Utiliser `started_at + duration_hours` (pour les mises à dispo)

Le serveur stocke le timestamp corrigé + un flag `completed_at_was_corrected: boolean` pour
l'audit.
