# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Agentic Blueprint — a landing page + Stripe checkout for selling PDF guides about building autonomous AI systems with Claude. Static HTML/CSS/JS frontend deployed on Vercel with a single serverless API endpoint.

## Tech Stack

- **Frontend:** Vanilla HTML/CSS/JavaScript (no framework, no build step)
- **Backend:** Single Vercel Serverless Function (`api/checkout.js`) using Node.js
- **Payments:** Stripe Checkout Sessions API (card-only)
- **Hosting:** Vercel (auto-deploys from GitHub `main` branch)
- **Fonts:** Inter + JetBrains Mono via Google Fonts CDN

## Commands

There is no build step, test suite, or linter. The project is static HTML.

```bash
# Install dependencies (only stripe SDK)
npm install

# Local development — use Vercel CLI
vercel dev

# Deploy (automatic via git push, or manual)
vercel --prod
```

## Architecture

### Pages
- `index.html` — Main landing page (AI agent "Butayaro" author variant)
- `human.html` — A/B test variant (human founder "Valentin Henry-Léo" author variant)
- `thank-you.html` — Post-purchase confirmation (receives `?session_id=&product=` query params)

### API
- `POST /api/checkout` — Creates a Stripe Checkout Session
  - Body: `{ product: 'guide1' | 'guide2' | 'bundle' }`
  - Returns: `{ url: '<stripe-checkout-url>' }`
  - Maps product names to env vars: `STRIPE_PRICE_GUIDE1`, `STRIPE_PRICE_GUIDE2`, `STRIPE_PRICE_BUNDLE`

### Checkout Flow
User clicks pricing CTA → `handleCheckout(product)` JS function → `POST /api/checkout` → Stripe session created → redirect to Stripe → payment → redirect to `thank-you.html`

### A/B Testing
`index.html` and `human.html` are identical except for the author section and footer tagline. When modifying shared sections (hero, pricing, FAQ, testimonials, chapters), changes must be applied to **both files**.

## Environment Variables (Vercel Secrets)

```
STRIPE_SECRET_KEY      — Stripe API secret key
STRIPE_PRICE_GUIDE1    — Price ID for Claude Code guide ($29)
STRIPE_PRICE_GUIDE2    — Price ID for OpenClaw guide ($29)
STRIPE_PRICE_BUNDLE    — Price ID for bundle ($44)
NEXT_PUBLIC_URL        — Deployed site base URL
```

## CSS Theming

Dark theme using CSS custom properties defined at the top of each HTML file:
- `--accent: #7c3aed` (purple), `--accent2: #a855f7` (light purple)
- `--green: #22c55e` (checkmarks, success), `--bg: #0a0a0a` (background)
- `--radius: 12px` (standard border radius)

## Content

The `pdf/` directory contains guide source content in Markdown/HTML (~4500 lines across 7 files). These are the source materials for the PDF products being sold.

## Commit Convention

Emoji-prefixed messages: 🚀 launch, ✨ feature, 💰 pricing, 👤 author/bio, 🔄 redeploy.
