# Leaderboard — architecture

Classement journalier et hebdomadaire entre utilisateurs de Handometer.

## Vue d'ensemble

```
┌─────────────┐  POST /api/leaderboard (toutes les 10 min)   ┌──────────────┐
│ App macOS   │ ───────────────────────────────────────────► │ Next.js API  │
│ (opt-in +   │                                              │ (web/, sur   │
│  pseudo)    │ ◄─────────────────────────────────────────── │  Vercel)     │
└─────────────┘  GET /api/leaderboard?period=daily|weekly    └──────┬───────┘
                                                                    │ REST
                                                             ┌──────▼───────┐
                                                             │ Upstash Redis│
                                                             │ (sorted sets)│
                                                             └──────────────┘
```

- **Score** : même barème que l'XP locale — `frappes + 0,1 × cm + 2 × clics`,
  calculé **côté serveur** à partir des compteurs bruts (le client n'envoie
  jamais de score).
- **Identité** : UUID aléatoire généré au premier opt-in + pseudo choisi par
  l'utilisateur. Aucun compte, aucun email, rien d'identifiant.
- **Vie privée** : seuls les totaux du jour partent (frappes, distance, clics).
  Jamais les `keyCounts` par touche. Opt-in explicite, désactivable.

## Stockage Redis

| Clé | Type | Contenu | TTL |
|-----|------|---------|-----|
| `lb:d:{YYYY-MM-DD}` | zset | score du jour par clientId | 3 jours |
| `lb:w:{YYYY-Www}` | zset | score de la semaine ISO par clientId | 35 jours |
| `lb:days:{YYYY-Www}:{clientId}` | hash | dayKey → score du jour | 35 jours |
| `lb:names` | hash | clientId → pseudo | — |

Écriture idempotente : le client envoie ses **totaux cumulés du jour**, le
serveur écrase (`ZADD`) — pas de double comptage, peu importe la fréquence
d'envoi. Le score hebdo est la somme des scores journaliers stockés dans le
hash `lb:days:…`, recalculée à chaque soumission.

## Choix assumés (v1)

- **Fuseaux horaires** : le bucket du jour est le `dayKey` local du client.
  Deux utilisateurs à Tokyo et Paris ne sont pas exactement sur la même
  fenêtre de 24 h. Acceptable pour un classement fun ; le serveur rejette
  seulement les dayKeys à plus de ±2 jours de sa propre date (anti-backfill).
- **Anti-triche** : système déclaratif avec garde-fous serveur — plafonds de
  vraisemblance par jour (300 k frappes, 5 km souris, 100 k clics). Pas de
  signature ni d'auth en v1 ; si abus, ajouter un HMAC embarqué + rate limit
  Upstash (`@upstash/ratelimit`).
- **Pseudo** : tronqué à 24 caractères, caractères de contrôle retirés.
  Collisions autorisées (l'identité est le UUID, pas le pseudo).

## Ce qu'il reste à faire ensemble (credentials)

1. **Déployer `web/` sur Vercel** (le site Next.js existant) :
   `cd web && vercel deploy --prod`.
2. **Créer la base Upstash Redis** via le Marketplace Vercel
   (`vercel integration add upstash`) — les variables
   `UPSTASH_REDIS_REST_URL` / `UPSTASH_REDIS_REST_TOKEN` (ou `KV_REST_API_*`)
   sont injectées automatiquement dans le projet. Free tier largement
   suffisant (10 k commandes/jour ≈ des centaines d'utilisateurs actifs).
3. **Renseigner l'URL de production** dans
   `Sources/Handometer/Leaderboard.swift` → `Leaderboard.baseURLString`
   (ex. `https://handometer.vercel.app`). Tant que la constante est vide,
   l'onglet Ranking affiche un état « pas encore disponible » et rien n'est
   envoyé.

## API

### POST `/api/leaderboard`

```json
{
  "clientId": "UUID",
  "name": "pseudo",
  "dayKey": "2026-07-15",
  "keystrokes": 12345,
  "distanceCm": 45678.9,
  "clicks": 2345
}
```

Réponse : `{ "ok": true, "score": 17605 }`

### GET `/api/leaderboard?period=daily|weekly&dayKey=2026-07-15&clientId=UUID`

```json
{
  "entries": [ { "rank": 1, "name": "…", "score": 99999, "isMe": false }, … ],
  "me": { "rank": 42, "score": 17605 }
}
```

Top 50 + rang du demandeur (si `clientId` fourni et présent dans le set).
