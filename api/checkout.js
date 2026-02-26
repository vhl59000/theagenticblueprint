const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const PRICE_IDS = {
  guide1: process.env.CLAUDE_CODE,  // Claude Code & Vibe Coding — $29
  guide2: process.env.OPENCLAW,     // OpenClaw Blueprint — $29
  bundle: process.env.BUNDLE,       // Full Stack Bundle — $44
};

module.exports = async (req, res) => {
  // Debug: log env vars (first 10 chars only for security)
  console.log('Env check:', {
    hasStripeKey: !!process.env.STRIPE_SECRET_KEY,
    stripeKeyPrefix: process.env.STRIPE_SECRET_KEY?.substring(0, 7),
    hasCLAUDE_CODE: !!process.env.CLAUDE_CODE,
    hasOPENCLAW: !!process.env.OPENCLAW,
    hasBUNDLE: !!process.env.BUNDLE,
  });

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { product = 'bundle' } = req.body || {};
  const priceId = PRICE_IDS[product] || PRICE_IDS.bundle;

  console.log('Checkout request:', { product, priceId });

  if (!priceId) {
    return res.status(500).json({ error: 'Price not configured for: ' + product });
  }

  try {
    console.log('Creating Stripe session with:', {
      priceId,
      mode: 'payment',
      success_url: `${process.env.NEXT_PUBLIC_URL}/thank-you.html`,
    });

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'payment',
      success_url: `${process.env.NEXT_PUBLIC_URL}/thank-you.html?session_id={CHECKOUT_SESSION_ID}&product=${product}`,
      cancel_url: `${process.env.NEXT_PUBLIC_URL}/#pricing`,
      metadata: { product },
    });

    console.log('Stripe session created:', session.id);
    res.status(200).json({ url: session.url });
  } catch (err) {
    console.error('Stripe error:', err.message);
    console.error('Stripe error type:', err.type);
    console.error('Stripe error full:', JSON.stringify(err, null, 2));
    res.status(500).json({ error: err.message });
  }
};
