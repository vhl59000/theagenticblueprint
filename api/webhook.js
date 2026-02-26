const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { Resend } = require('resend');

const resend = new Resend(process.env.RESEND_API_KEY);

// Map product keys to download URLs + names
const PRODUCTS = {
  guide1: {
    name: 'Guide 01 — Claude Code & Vibe Coding',
    url: `${process.env.NEXT_PUBLIC_URL}/downloads/guide1.pdf`,
  },
  guide2: {
    name: 'Guide 02 — The OpenClaw Blueprint',
    url: `${process.env.NEXT_PUBLIC_URL}/downloads/guide2.pdf`,
  },
  bundle: {
    name: 'Full Stack Bundle (Guide 01 + Guide 02)',
    urls: [
      `${process.env.NEXT_PUBLIC_URL}/downloads/guide1.pdf`,
      `${process.env.NEXT_PUBLIC_URL}/downloads/guide2.pdf`,
    ],
  },
};

function buildEmailHtml(customerEmail, product, productKey) {
  const isBundle = productKey === 'bundle';
  const downloadLinks = isBundle
    ? product.urls.map((url, i) =>
        `<a href="${url}" style="display:inline-block;margin:8px 0;padding:12px 24px;background:#7c3aed;color:#fff;text-decoration:none;border-radius:8px;font-weight:600;">
          Download Guide 0${i + 1} ↓
        </a>`
      ).join('<br>')
    : `<a href="${product.url}" style="display:inline-block;margin:8px 0;padding:12px 24px;background:#7c3aed;color:#fff;text-decoration:none;border-radius:8px;font-weight:600;">
        Download your guide ↓
      </a>`;

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="background:#0a0a0a;color:#fff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:0;padding:0;">
  <div style="max-width:600px;margin:0 auto;padding:48px 24px;">
    <div style="text-align:center;margin-bottom:32px;">
      <span style="font-size:48px;">🐷</span>
      <h1 style="color:#fff;font-size:28px;margin:16px 0 8px;">You're in.</h1>
      <p style="color:#888;margin:0;">Thanks for getting <strong style="color:#fff;">${product.name}</strong>.</p>
    </div>

    <div style="background:#111;border:1px solid #222;border-radius:12px;padding:32px;margin-bottom:24px;text-align:center;">
      <p style="color:#aaa;margin:0 0 24px;font-size:15px;">Your download link is ready:</p>
      ${downloadLinks}
      <p style="color:#555;font-size:12px;margin:16px 0 0;">Links expire in 7 days. Save the PDF once downloaded.</p>
    </div>

    <div style="background:#111;border:1px solid #222;border-radius:12px;padding:24px;margin-bottom:24px;">
      <p style="color:#888;font-size:13px;text-transform:uppercase;letter-spacing:1px;margin:0 0 16px;">// What to do next</p>
      <p style="color:#ccc;margin:0 0 12px;">1. <strong style="color:#fff;">Start with Chapter 1</strong> — the mental shift that makes everything else click. 10 minutes.</p>
      <p style="color:#ccc;margin:0 0 12px;">2. <strong style="color:#fff;">Pick one workflow and implement it today</strong> — don't wait until you've read everything.</p>
      <p style="color:#ccc;margin:0;">3. <strong style="color:#fff;">Got stuck?</strong> Reply to this email. I answer personally, 24/7.</p>
    </div>

    <div style="text-align:center;border-top:1px solid #222;padding-top:24px;">
      <p style="color:#555;font-size:12px;margin:0;">
        The Agentic Blueprint · <a href="https://theagenticblueprint.com" style="color:#7c3aed;">theagenticblueprint.com</a>
      </p>
    </div>
  </div>
</body>
</html>`;
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    // Get raw body for Stripe signature verification
    const rawBody = await getRawBody(req);
    event = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature error:', err.message);
    return res.status(400).json({ error: `Webhook error: ${err.message}` });
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const customerEmail = session.customer_details?.email;
    const productKey = session.metadata?.product || 'bundle';
    const product = PRODUCTS[productKey] || PRODUCTS.bundle;

    console.log('Sending email to:', customerEmail, 'product:', productKey);

    try {
      await resend.emails.send({
        from: 'The Agentic Blueprint <hello@theagenticblueprint.com>',
        to: [customerEmail],
        subject: `Your copy of ${product.name} is here 🐷`,
        html: buildEmailHtml(customerEmail, product, productKey),
      });
      console.log('Email sent successfully to:', customerEmail);
    } catch (emailErr) {
      console.error('Email send error:', emailErr.message);
      // Don't fail the webhook — log and continue
    }
  }

  res.status(200).json({ received: true });
};

// Parse raw body for Stripe signature verification
// Handles both Vercel auto-parsed and raw stream cases
function getRawBody(req) {
  // If Vercel already parsed the body, re-serialize it
  if (req.body) {
    const raw = Buffer.isBuffer(req.body)
      ? req.body
      : typeof req.body === 'string'
        ? req.body
        : JSON.stringify(req.body);
    return Promise.resolve(raw);
  }
  // Otherwise read raw from stream
  return new Promise((resolve, reject) => {
    let chunks = [];
    req.on('data', chunk => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}
