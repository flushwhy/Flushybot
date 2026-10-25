const express = require("express");
const Stripe = require("stripe");
const fs = require("node:fs");
const path = require("node:path");

const required = ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "DISCORD_BOT_TOKEN", "DISCORD_GUILD_ID", "BOT_SERVICE_TOKEN"];
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required environment variable: ${key}`);
}

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const app = express();
const port = Number(process.env.PORT || 3000);
const statePath = path.join(__dirname, "stripe-state.json");
const state = fs.existsSync(statePath)
  ? JSON.parse(fs.readFileSync(statePath, "utf8"))
  : { timeouts: {}, processedEvents: [] };

function saveState() {
  const tempPath = statePath + ".tmp";
  fs.writeFileSync(tempPath, JSON.stringify(state, null, 2), { mode: 0o600 });
  fs.renameSync(tempPath, statePath);
}

function timeoutKey(guildId, userId) {
  return `${guildId}:${userId}`;
}

function authorized(req, res, next) {
  const expected = `Bearer ${process.env.BOT_SERVICE_TOKEN}`;
  if (req.get("authorization") !== expected) return res.status(401).json({ error: "Unauthorized" });
  next();
}

// Stripe signature verification requires the unparsed request body.
app.post("/stripe/webhook", express.raw({ type: "application/json" }), async (req, res) => {
  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, req.get("stripe-signature"), process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Invalid webhook signature: ${err.message}`);
  }

  if (state.processedEvents.includes(event.id)) return res.json({ received: true, duplicate: true });

  try {
    if (event.type === "checkout.session.completed") {
      const session = event.data.object;
      if (session.mode === "payment" && session.payment_status === "paid") {
        const redeemed = await redeem(session);
        if (!redeemed) {
          if (!session.payment_intent) throw new Error("Paid Checkout Session has no PaymentIntent to refund.");
          await stripe.refunds.create(
            { payment_intent: session.payment_intent },
            { idempotencyKey: `refund-${session.id}` }
          );
          console.log(`Refunded Checkout ${session.id}: the original Muteoulette timeout was no longer eligible.`);
        }
      }
    }

    state.processedEvents.push(event.id);
    if (state.processedEvents.length > 2000) state.processedEvents.splice(0, state.processedEvents.length - 2000);
    saveState();
    res.json({ received: true });
  } catch (err) {
    console.error("Webhook processing failed:", err);
    res.status(500).json({ error: "Webhook processing failed; Stripe may retry." });
  }
});

app.use(express.json({ limit: "16kb" }));

app.post("/internal/timeouts", authorized, (req, res) => {
  const { guildId, userId, timeoutUntil } = req.body || {};
  if (guildId !== process.env.DISCORD_GUILD_ID || !/^\d{17,20}$/.test(String(userId || ""))) {
    return res.status(400).json({ error: "Invalid guild or user." });
  }
  const until = Date.parse(timeoutUntil);
  if (!Number.isFinite(until) || until <= Date.now() || until > Date.now() + 25 * 60 * 1000) {
    return res.status(400).json({ error: "Invalid timeout expiry." });
  }
  state.timeouts[timeoutKey(guildId, userId)] = { timeoutUntil: new Date(until).toISOString() };
  saveState();
  res.json({ ok: true });
});

app.post("/internal/checkout", authorized, async (req, res) => {
  try {
    const { guildId, userId, amountCents } = req.body || {};
    if (guildId !== process.env.DISCORD_GUILD_ID || !/^\d{17,20}$/.test(String(userId || ""))) {
      return res.status(400).json({ error: "Invalid guild or user." });
    }
    if (![200, 300, 400].includes(Number(amountCents))) {
      return res.status(400).json({ error: "Choose $2, $3, or $4." });
    }
    const active = state.timeouts[timeoutKey(guildId, userId)];
    if (!active || Date.parse(active.timeoutUntil) <= Date.now()) {
      return res.status(409).json({ error: "No active Muteoulette timeout was found for this account." });
    }

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      client_reference_id: userId,
      line_items: [{
        price_data: {
          currency: "usd",
          unit_amount: Number(amountCents),
          product_data: { name: "Flushybot early unmute donation" }
        },
        quantity: 1
      }],
      metadata: { guildId, userId, timeoutUntil: active.timeoutUntil },
      success_url: process.env.CHECKOUT_SUCCESS_URL || "https://discord.com/app",
      cancel_url: process.env.CHECKOUT_CANCEL_URL || "https://discord.com/app"
    }, { idempotencyKey: `checkout-${guildId}-${userId}-${Date.now()}` });

    res.json({ url: session.url });
  } catch (err) {
    console.error("Checkout creation failed:", err);
    res.status(500).json({ error: "Could not create checkout session." });
  }
});

async function redeem(session) {
  const { guildId, userId, timeoutUntil } = session.metadata || {};
  if (guildId !== process.env.DISCORD_GUILD_ID || userId !== session.client_reference_id) return;
  if (!/^\d{17,20}$/.test(String(userId || ""))) return;

  const key = timeoutKey(guildId, userId);
  const active = state.timeouts[key];
  if (!active || active.timeoutUntil !== timeoutUntil || Date.parse(active.timeoutUntil) <= Date.now()) return false;

  const base = `https://discord.com/api/v10/guilds/${guildId}/members/${userId}`;
  const headers = { Authorization: `Bot ${process.env.DISCORD_BOT_TOKEN}` };
  const memberResponse = await fetch(base, { headers });
  if (memberResponse.status === 404) return false;
  if (!memberResponse.ok) throw new Error(`Discord member lookup failed: ${memberResponse.status}`);
  const member = await memberResponse.json();
  if (!member.communication_disabled_until) {
    delete state.timeouts[key];
    saveState();
    return false;
  }

  const actualUntil = Date.parse(member.communication_disabled_until);
  const expectedUntil = Date.parse(active.timeoutUntil);
  // Do not remove a timeout that appears to have been changed by a moderator.
  if (!Number.isFinite(actualUntil) || Math.abs(actualUntil - expectedUntil) > 90_000) return false;

  const response = await fetch(base, {
    method: "PATCH",
    headers: { ...headers, "Content-Type": "application/json" },
    body: JSON.stringify({ communication_disabled_until: null })
  });
  if (!response.ok) throw new Error(`Discord timeout removal failed: ${response.status}`);

  delete state.timeouts[key];
  saveState();
  console.log(`Early unmute granted for Discord user ${userId} via Checkout ${session.id}`);
  return true;
}

app.listen(port, () => console.log(`Stripe service listening on port ${port}`));
