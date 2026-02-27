#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  The Agentic Blueprint — Launch Readiness Check
#  Usage: ./scripts/launch-check.sh
#  Runs a full audit of every component needed before going live.
# ══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

BASE_URL="${NEXT_PUBLIC_URL:-https://www.theagenticblueprint.com}"
ENV_FILE="$(dirname "$0")/../.env"

# Load .env if present
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs) 2>/dev/null || true
fi

# ── Colors ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARN++)); }
section() { echo -e "\n${BOLD}${BLUE}── $1 ──────────────────────────────────────${NC}"; }

echo ""
echo -e "${BOLD}🐷 The Agentic Blueprint — Launch Readiness Check${NC}"
echo -e "   $(date '+%Y-%m-%d %H:%M UTC')"
echo -e "   Target: $BASE_URL"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
section "1. ENVIRONMENT VARIABLES"
# ══════════════════════════════════════════════════════════════════════════════

required_vars=(
  "STRIPE_SECRET_KEY"
  "STRIPE_PUBLISHABLE_KEY"
  "STRIPE_WEBHOOK_SECRET"
  "STRIPE_PRICE_ID"
  "RESEND_API_KEY"
  "NEXT_PUBLIC_URL"
)

for var in "${required_vars[@]}"; do
  if [ -n "${!var:-}" ]; then
    val="${!var}"
    preview="${val:0:12}..."
    pass "$var is set ($preview)"
  else
    fail "$var is MISSING"
  fi
done

# Check Stripe mode
if [[ "${STRIPE_SECRET_KEY:-}" == sk_live_* ]]; then
  pass "Stripe is in LIVE mode ✓"
elif [[ "${STRIPE_SECRET_KEY:-}" == sk_test_* ]]; then
  fail "Stripe is in TEST mode — switch to sk_live_ before launch"
else
  warn "Cannot determine Stripe mode from key"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "2. CHECKOUT API"
# ══════════════════════════════════════════════════════════════════════════════

for product in bundle guide1 guide2; do
  RESPONSE=$(curl -s -X POST "$BASE_URL/api/checkout" \
    -H "Content-Type: application/json" \
    -d "{\"product\":\"$product\"}" \
    --max-time 15 2>/dev/null || echo '{"error":"timeout"}')

  if echo "$RESPONSE" | grep -q '"url"'; then
    pass "Checkout /api/checkout [product=$product] → 200 with Stripe URL"
  else
    ERR=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error','unknown'))" 2>/dev/null || echo "$RESPONSE")
    fail "Checkout [product=$product] failed: $ERR"
  fi
done

# ══════════════════════════════════════════════════════════════════════════════
section "3. PDF DOWNLOADS"
# ══════════════════════════════════════════════════════════════════════════════

for guide in guide1 guide2; do
  RESP=$(curl -s -I "$BASE_URL/downloads/$guide.pdf" --max-time 10 2>/dev/null)
  HTTP_CODE=$(echo "$RESP" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
  CONTENT_TYPE=$(echo "$RESP" | grep -i "^content-type" | awk '{print $2}' | tr -d '\r')
  
  if [ "$HTTP_CODE" = "200" ]; then
    pass "/downloads/$guide.pdf → HTTP $HTTP_CODE ($CONTENT_TYPE)"
  else
    fail "/downloads/$guide.pdf → HTTP $HTTP_CODE (expected 200)"
  fi
done

# ══════════════════════════════════════════════════════════════════════════════
section "4. STRIPE CONFIGURATION"
# ══════════════════════════════════════════════════════════════════════════════

if [ -n "${STRIPE_SECRET_KEY:-}" ]; then
  PRICES=$(curl -s "https://api.stripe.com/v1/prices?limit=20&expand[]=data.product" \
    -u "${STRIPE_SECRET_KEY}:" \
    --max-time 10 2>/dev/null)

  if echo "$PRICES" | grep -q '"id"'; then
    PRICE_COUNT=$(echo "$PRICES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" 2>/dev/null || echo "?")
    pass "Stripe API accessible ($PRICE_COUNT active prices)"
    
    # Check for $44 bundle
    if echo "$PRICES" | grep -q '"unit_amount": 4400'; then
      pass "Bundle price (\$44) found in Stripe"
    elif echo "$PRICES" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(p['unit_amount']) for p in d['data']]" 2>/dev/null | grep -q "4400"; then
      pass "Bundle price (\$44) found in Stripe"
    else
      warn "Bundle \$44 price not detected — check STRIPE_PRICE_ID"
    fi
    
    # Check for $29 guide prices
    PRICES_29=$(echo "$PRICES" | python3 -c "import sys,json; d=json.load(sys.stdin); c=[p for p in d['data'] if p['unit_amount']==2900]; print(len(c))" 2>/dev/null || echo "0")
    if [ "$PRICES_29" -ge 2 ] 2>/dev/null; then
      pass "\$29 prices: $PRICES_29 found (guide1 + guide2)"
    else
      warn "Expected 2 × \$29 prices, found $PRICES_29"
    fi
  else
    fail "Stripe API not accessible with current key"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
section "5. STRIPE WEBHOOK"
# ══════════════════════════════════════════════════════════════════════════════

if [ -n "${STRIPE_SECRET_KEY:-}" ]; then
  WEBHOOKS=$(curl -s "https://api.stripe.com/v1/webhook_endpoints" \
    -u "${STRIPE_SECRET_KEY}:" \
    --max-time 10 2>/dev/null)

  WEBHOOK_URL=$(echo "$WEBHOOKS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
wh=[w for w in d.get('data',[]) if 'theagenticblueprint' in w.get('url','')]
if wh: print(wh[0]['url'], wh[0]['status'])
" 2>/dev/null || echo "")

  if [ -n "$WEBHOOK_URL" ]; then
    pass "Stripe webhook: $WEBHOOK_URL"
    if echo "$WEBHOOK_URL" | grep -q "enabled"; then
      pass "Webhook is enabled"
    else
      warn "Webhook status: $WEBHOOK_URL"
    fi
  else
    fail "No Stripe webhook found pointing to theagenticblueprint.com"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
section "6. EMAIL (RESEND)"
# ══════════════════════════════════════════════════════════════════════════════

if [ -n "${RESEND_API_KEY:-}" ]; then
  # Try to list domains (will fail on send-only key, but that's OK)
  RESEND_CHECK=$(curl -s "https://api.resend.com/domains" \
    -H "Authorization: Bearer ${RESEND_API_KEY}" \
    --max-time 10 2>/dev/null)

  if echo "$RESEND_CHECK" | grep -q "restricted_api_key\|data"; then
    pass "Resend API key is valid"
    
    VERIFIED=$(echo "$RESEND_CHECK" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  domains=[dom for dom in d.get('data',[]) if dom.get('status')=='verified']
  print(len(domains), [dom['name'] for dom in domains])
except: print('restricted')
" 2>/dev/null || echo "restricted")
    
    if echo "$VERIFIED" | grep -q "restricted"; then
      warn "Resend key is send-only (can't check domain verification) — verify manually"
    elif echo "$VERIFIED" | grep -q "theagenticblueprint"; then
      pass "Domain theagenticblueprint.com verified in Resend ✓"
    else
      warn "Domain verification status unknown — check Resend dashboard"
    fi
  else
    fail "Resend API key invalid or unreachable"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
section "7. VERCEL DEPLOYMENT"
# ══════════════════════════════════════════════════════════════════════════════

if [ -n "${VERCEL_TOKEN:-}" ]; then
  LATEST=$(curl -s "https://api.vercel.com/v6/deployments?projectId=theagenticblueprint&limit=1" \
    -H "Authorization: Bearer ${VERCEL_TOKEN}" \
    --max-time 10 2>/dev/null)

  if echo "$LATEST" | grep -q '"state"'; then
    STATE=$(echo "$LATEST" | python3 -c "
import sys,json
d=json.load(sys.stdin)
deps=d.get('deployments',[])
if deps: print(deps[0].get('state','?'), deps[0].get('url','?'))
" 2>/dev/null || echo "?")
    
    if echo "$STATE" | grep -qi "ready"; then
      pass "Latest Vercel deployment: READY ✓"
    else
      warn "Latest Vercel deployment: $STATE"
    fi
  else
    warn "Could not check Vercel deployment status"
  fi
fi

# Site responds
SITE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" --max-time 10 2>/dev/null || echo "000")
if [ "$SITE" = "200" ]; then
  pass "Site is live: $BASE_URL → HTTP $SITE"
else
  fail "Site not responding: $BASE_URL → HTTP $SITE"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "8. SEND-EMAIL API"
# ══════════════════════════════════════════════════════════════════════════════

# Test with a fake session_id — expect an error but NOT a 500 crash
EMAIL_RESP=$(curl -s -X POST "$BASE_URL/api/send-email" \
  -H "Content-Type: application/json" \
  -d '{"session_id":"cs_test_fake123","product":"bundle"}' \
  --max-time 15 2>/dev/null || echo '{"error":"timeout"}')

if echo "$EMAIL_RESP" | grep -q '"error"'; then
  ERR=$(echo "$EMAIL_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error','?'))" 2>/dev/null || echo "?")
  if echo "$ERR" | grep -qi "stripe\|session\|No such\|invalid"; then
    pass "Send-email endpoint is live (returns Stripe validation error as expected)"
  else
    warn "Send-email returned unexpected error: $ERR"
  fi
else
  pass "Send-email endpoint responding"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "SUMMARY"
# ══════════════════════════════════════════════════════════════════════════════

TOTAL=$((PASS + FAIL + WARN))
echo ""
echo -e "  ${GREEN}✓ PASS${NC}: $PASS"
echo -e "  ${YELLOW}⚠ WARN${NC}: $WARN"
echo -e "  ${RED}✗ FAIL${NC}: $FAIL"
echo -e "  Total checks: $TOTAL"
echo ""

if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}🚀 ALL SYSTEMS GO. Ready to launch.${NC}"
elif [ $FAIL -eq 0 ]; then
  echo -e "  ${YELLOW}${BOLD}⚠ ALMOST THERE. $WARN warning(s) to review before going live.${NC}"
else
  echo -e "  ${RED}${BOLD}🛑 NOT READY. $FAIL blocker(s) must be fixed.${NC}"
fi
echo ""
