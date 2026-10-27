# Flushybot

A small Discord bot written in Lua with Discordia.

## Bot setup

1. Install Luvit, Lit, Discordia, and the dependencies listed in `init.lua`.
2. Copy `.env.example` to `.env` and set your Discord bot token.
3. Enable the **Message Content Intent** in the Discord Developer Portal.
4. Invite the bot with **Send Messages**, **Moderate Members**, and **Send Messages in DMs** permissions as needed.
5. Run the bot using your usual Luvit/Lit workflow.

## Commands

- `!ping` — check whether the bot is online.
- `!hello` — says hello.
- `!help` — lists commands.
- `!muteoulette` — 1-in-5 chance to escape; otherwise applies a 5, 10, 15, or 20 minute Discord timeout.
- `!donate [2|3|4]` — request a $2, $3, or $4 Stripe Checkout link for an active Muteoulette timeout. The default is $3.
- `!msg <text>` — repeats text.

## Stripe early-unmute service

The Stripe integration is a small Node.js companion service in `stripe-service/`. It must be hosted at a public HTTPS URL and run alongside the Lua bot.

1. Install Node.js 18 or newer, then run `npm install` inside `stripe-service/`.
2. Copy `stripe-service/.env.example` to `stripe-service/.env`.
3. Set `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` from Stripe. Start in test mode first.
4. Set `DISCORD_BOT_TOKEN` and `DISCORD_GUILD_ID`. The bot needs **Moderate Members** permission and its highest role above members it times out.
5. Generate a long random value for `BOT_SERVICE_TOKEN`; set the exact same value as `STRIPE_SERVICE_TOKEN` in the Lua bot's `.env`.
6. Set `STRIPE_SERVICE_URL` in the bot's `.env` to the companion service's public HTTPS base URL.
7. Deploy the service and configure a Stripe webhook endpoint at `https://YOUR_HOST/stripe/webhook` for `checkout.session.completed`. Copy its signing secret to `STRIPE_WEBHOOK_SECRET`.
8. Run the service with `npm start`, then restart the Lua bot.

The service records only timeouts registered after Muteoulette, creates one-time Checkout Sessions for $2/$3/$4, verifies Stripe's webhook signature, and only removes the timeout if Discord's current expiry still matches the recorded Muteoulette timeout. It does not intentionally clear unrelated moderator timeouts. Keep `stripe-service/.env` and `stripe-state.json` private and persistent; never commit API keys or webhook secrets.

**Important:** this first implementation is not tested against your hosting setup or installed Discordia/Luvit versions. Test with Stripe test mode and a test Discord server before accepting real payments. Ensure the host provides persistent storage for `stripe-state.json`; this lightweight state file is for a single service instance, not multi-instance hosting.
