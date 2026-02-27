# GO-LIVE Checklist — The Agentic Blueprint
*Dernière mise à jour : 27 février 2026 — Butayaro Night Shift*

> Audit complet fait cette nuit. Bonne nouvelle : la stack est quasi prête. Voici exactement quoi faire pour aller en prod.

---

## État actuel (27/02/2026)

| Composant | Status | Note |
|-----------|--------|------|
| Checkout API | ✅ OK | Fonctionne pour bundle + guide1 + guide2 |
| PDFs | ✅ OK | guide1.pdf + guide2.pdf accessibles en prod |
| Stripe Webhook | ✅ OK | Configuré sur checkout.session.completed |
| Resend API | ✅ OK | Clé valide, send-email endpoint up |
| Email delivery | ✅ Built | webhook.js → Resend → PDF links |
| **Stripe mode** | 🔴 TEST | **BLOQUANT** — sk_test_*, pas de vrai argent |
| **Stripe live prices** | 🔴 À créer | **BLOQUANT** — les prices actuels sont en test mode |
| **Resend domain** | ⚠️ À vérifier | hello@theagenticblueprint.com doit être vérifié |
| A/B test (human.html) | ✅ OK | Route /human → human.html |

---

## Les 6 étapes pour aller LIVE

### Étape 1 — Vérifier le domaine dans Resend (10 min)

1. Va sur [resend.com/domains](https://resend.com/domains)
2. Ajoute `theagenticblueprint.com`
3. Copie les DNS records (DKIM + SPF)
4. Ajoute-les dans ton registrar (où est le domaine ?)
5. Attends 5-15 min, vérifie "Verified" ✓

**Pourquoi :** Sans ça, les emails sortent de `onboarding@resend.dev`, pas de `hello@theagenticblueprint.com`. Clients pas rassurés.

---

### Étape 2 — Créer les prices LIVE sur Stripe (15 min)

Stripe LIVE ≠ Stripe TEST. Tes prices actuels sont **uniquement en test**.

1. Va sur [dashboard.stripe.com](https://dashboard.stripe.com) → bascule en **Live mode** (toggle en haut à droite)
2. Créer 3 produits :

**Guide 01 — Claude Code & Vibe Coding — $29**
```
Produits → + Ajouter un produit
Nom : Guide 01 — Claude Code & Vibe Coding
Prix : $29.00 USD — ponctuel
→ Note l'ID : price_live_XXXXXXXXX (c'est STRIPE_PRICE_GUIDE1)
```

**Guide 02 — The OpenClaw Blueprint — $29**
```
Produits → + Ajouter un produit
Nom : Guide 02 — The OpenClaw Blueprint
Prix : $29.00 USD — ponctuel
→ Note l'ID : price_live_XXXXXXXXX (c'est STRIPE_PRICE_GUIDE2)
```

**Bundle Full Stack — $44**
```
Produits → + Ajouter un produit
Nom : Full Stack Bundle (Guide 01 + Guide 02)
Prix : $44.00 USD — ponctuel
→ Note l'ID : price_live_XXXXXXXXX (c'est STRIPE_PRICE_BUNDLE)
```

---

### Étape 3 — Récupérer les clés LIVE Stripe (5 min)

1. Stripe dashboard → **Développeurs → Clés API** (en mode LIVE)
2. Note :
   - `Clé publiable` → commence par `pk_live_...`
   - `Clé secrète` → commence par `sk_live_...`

---

### Étape 4 — Créer le webhook LIVE Stripe (5 min)

1. Stripe → **Développeurs → Webhooks → + Ajouter un endpoint**
2. URL : `https://www.theagenticblueprint.com/api/webhook`
3. Événements : `checkout.session.completed`
4. Note le **Webhook signing secret** → commence par `whsec_...`

---

### Étape 5 — Mettre à jour les env vars sur Vercel (10 min)

Va sur [vercel.com](https://vercel.com) → theagenticblueprint → Settings → Environment Variables.

**Remplace** les variables suivantes (supprimer les anciennes + ajouter les nouvelles) :

```
STRIPE_SECRET_KEY        = sk_live_...
STRIPE_PUBLISHABLE_KEY   = pk_live_...
STRIPE_WEBHOOK_SECRET    = whsec_live_...
CLAUDE_CODE              = price_live_... (Guide 01 $29)
OPENCLAW                 = price_live_... (Guide 02 $29)
BUNDLE                   = price_live_... (Bundle $44)
STRIPE_PRICE_ID          = price_live_... (Bundle $44 — même valeur que BUNDLE)
NEXT_PUBLIC_URL          = https://www.theagenticblueprint.com
RESEND_API_KEY           = re_... (inchangé — même clé marche en prod)
```

---

### Étape 6 — Redéployer + tester (10 min)

```bash
cd /root/.openclaw/workspace/theagenticblueprint
vercel --prod --token=$VERCEL_TOKEN --yes
```

Puis vérifier :
```bash
./scripts/launch-check.sh
```

Test final : achète le bundle avec une vraie carte Visa, vérifie l'email → PDF arrivé.

---

## Notes techniques (pour Butayaro)

### Mapping env vars → checkout.js
```js
guide1: process.env.CLAUDE_CODE
guide2: process.env.OPENCLAW
bundle: process.env.BUNDLE
```
Ces 3 vars sont bien settées sur Vercel. Le checkout fonctionne.

### Flow email complet
```
User clique Buy
  → POST /api/checkout → Stripe Checkout Session créée
  → User paie sur Stripe
  → Stripe déclenche webhook: checkout.session.completed
  → POST /api/webhook → Resend envoie email avec liens PDF
  → thank-you.html aussi déclenche POST /api/send-email (backup)
```
Double trigger intentionnel = 0 chance de rater l'email.

### Les PDFs en prod
- Location : `/downloads/guide1.pdf` + `/downloads/guide2.pdf`
- Trackés dans git (commités avant le `.gitignore *.pdf`)
- HTTP 200 confirmé sur les deux ✓
- **Pour les updater** : supprimer de gitignore, commit, push, redeploy

### Script de check
```bash
./scripts/launch-check.sh
```
Audite tout : env vars, checkout API, PDFs, Stripe, Resend, Vercel, email endpoint.

---

## Budget temps total estimé

| Étape | Temps |
|-------|-------|
| Resend domain verification | 10 min |
| Stripe LIVE prices | 15 min |
| Récupérer clés LIVE | 5 min |
| Setup webhook LIVE | 5 min |
| Update Vercel env vars | 10 min |
| Redeploy + test | 10 min |
| **Total** | **~55 min** |

---

**TL;DR : 1h de boulot et c'est live. Le code est prêt. Il manque juste les clés LIVE.**

🐷 *— Butayaro, 3h du mat*
