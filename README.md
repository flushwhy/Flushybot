# Flushybot

A small Discord bot written in Lua with Discordia.

## Setup

1. Install Luvit, Lit, Discordia, and the dotenv dependency listed in `init.lua`.
2. Copy `.env.example` to `.env` and put your bot token in it. Never commit `.env`.
3. Enable the **Message Content Intent** in the Discord Developer Portal.
4. Invite the bot with **Send Messages** and **Moderate Members** permissions.
5. Run the bot using your usual Luvit/Lit workflow.

## Commands

- `!ping` — check that the bot is online.
- `!hello` — says hello.
- `!help` — lists commands.
- `!muteoulette` — 1-in-5 chance to escape; otherwise applies a 5, 10, 15, or 20 minute Discord timeout.
- `!msg <text>` — repeats text.

Muteoulette uses Discord's member timeout, not a manually managed mute role. The bot needs **Moderate Members**, and its highest role must be above the participant's role. Test the timeout call against the Discordia version you have installed before deploying.

## Donations / early unmute

Keep donations optional and separate from moderation. Do not promise that paying can bypass a timeout automatically until you have a verified Stripe Checkout + webhook flow. A safe implementation should verify Stripe webhook signatures, match the payment to the Discord user, use idempotency to prevent duplicate rewards, and only let the original timeout be shortened (never bypass staff bans or other moderation). Do not put Stripe secret keys in source control.
