# Agent Streak — Submission Draft

> **Status:** DRAFT — awaiting contract address, live website URL, and GitHub repo URL from the build team. Do not submit until all TBD fields are filled and verified.

## Project Name

**Agent Streak**

## Tagline

Daily check-in for Agent ID holders — build your streak, earn soulbound badges, prove you're here to stay.

## Project Description

Every on-chain community faces the same problem: how do you tell real, committed participants from passing traffic? Most engagement tools rely on off-chain points that can be farmed, faked, or wiped by a database reset. There is no portable, verifiable record of a user's daily commitment — and no identity anchor that makes that record meaningful across the ecosystem.

Agent Streak solves this with a simple daily ritual, fully on-chain. Holders of a Binance Agent ID check in once per day (UTC) by calling `checkIn()` on the smart contract. Consecutive check-ins build a streak that lives on-chain and is visible to anyone. At streak milestones of 7, 14, and 30 days, holders can claim soulbound ERC-721 badges — non-transferable proof of consistency tied to their Agent ID holder address. A public leaderboard, built from on-chain events, ranks the most consistent agents. No deposits, no paid mints, no funds held: the only cost is gas.

Agent ID is the core of this product, not an add-on. The entire mechanic — gating, identity, and reward — only works because Agent ID exists as a verifiable, on-chain agent identity. Without it, a check-in dApp would be a meaningless button anyone could spam; with it, every streak is anchored to a real agent identity, every badge is proof of a specific agent's commitment, and the leaderboard is a leaderboard of *agents*, not anonymous wallets.

## How Agent ID Is Used (core judging criterion — 30%)

1. **Gating (access control).** `checkIn()` reverts unless the caller's Agent ID balance is greater than zero (`balanceOf > 0`). Non-holders cannot check in, cannot build a streak, and cannot claim badges. Agent ID is the only key to the product.
2. **Streak identity.** Each streak is recorded per Agent ID holder address. The streak *is* the agent's on-chain reputation of consistency — portable, public, and impossible to fake without holding an Agent ID and showing up every day.
3. **Soulbound badges bound to Agent ID holders.** `claimBadge(7 / 14 / 30)` mints a non-transferable ERC-721 badge only to addresses that hold an Agent ID and have reached the milestone. Badges are proof of an *agent's* track record, not a tradable collectible.
4. **Leaderboard of agents.** The leaderboard ranks Agent ID holders by streak and badge count, sourced entirely from on-chain events — a public, verifiable ranking of the most consistent agents in the ecosystem.

## Features

- **Daily check-in (1×/day, UTC)** — on-chain, gated by Agent ID ownership.
- **On-chain consecutive streaks** — streaks are computed and stored in the contract; missing a day resets the streak.
- **Soulbound milestone badges** — ERC-721 badges at 7, 14, and 30-day streaks; non-transferable by design.
- **Public leaderboard** — ranked from on-chain events; no off-chain database.
- **No funds at risk** — no deposits, no paid mints, no user funds held by the contract. Gas only.
- **Minimal owner permissions** — the contract owner can only trigger an emergency pause; no minting, no fund movement, no user-state manipulation.
- **Privacy-friendly frontend** — static site, connect via injected provider (MetaMask / Rabby / Binance Wallet); no QR login, no session storage, the user confirms every transaction themselves.

## Submission Details

| Field | Value |
|---|---|
| Project name | Agent Streak |
| Website URL | TBD |
| Contract address (BNB Chain) | TBD |
| GitHub repo URL (open-source) | TBD |
| BscScan verified source | TBD (link after verification) |
| Reward receiving address | TBD — to be filled by the project lead |
| Category / Award targeted | Innovation Award (primary); Growth Award (metrics) |

## Notes for the Submitter

- The project targets the **Innovation Award** (live product + at least 30 Agent ID addresses interacting with the contract during the submission period). The same on-chain activity also counts toward the Growth Award metrics, but a project can only win one award.
- This project is not affiliated with or endorsed by Binance. "Binance Agent ID Hackathon" is referenced only as the name of the event this project is submitted to.
- No returns, rewards, or earnings are promised to users anywhere in the product or materials.
