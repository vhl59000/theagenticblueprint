const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const PRICE_IDS = {
  guide1:  process.env.STRIPE_PRICE_GUIDE1  || process.env.STRIPE_PRICE_ID, // Claude Code & Vibe Coding — $29
  guide2:  process.env.STRIPE_PRICE_GUIDE2  || process.env.STRIPE_PRICE_ID, // OpenClaw Blueprint — $29
  bundle:  process.env.STRIPE_PRICE_BUNDLE  || process.env.STRIPE_PRICE_ID, // Full Stack Bundle — $45
};

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { product = 'bundle' } = req.body || {};
  const priceId = PRICE_IDS[product] || PRICE_IDS.bundle;

  if (!priceId) {
    return res.status(500).json({ error: 'Price not configured for: ' + product });
  }

  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      mode: 'payment',
      success_url: `${process.env.NEXT_PUBLIC_URL}/thank-you.html?session_id={CHECKOUT_SESSION_ID}&product=${product}`,
      cancel_url: `${process.env.NEXT_PUBLIC_URL}/#pricing`,
      metadata: { product },
    });

    res.status(200).json({ url: session.url });
  } catch (err) {
    console.error('Stripe error:', err.message);
    res.status(500).json({ error: err.message });
  }
};
