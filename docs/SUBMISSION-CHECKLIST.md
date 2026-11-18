# Agent Streak — Submission Checklist

> Submission window: **18 Nov 2026 08:00 UTC – 9 Dec 2026 08:00 UTC**
> Internal deploy deadline (parent target): **25 Nov 2026**
> Internal review: 9–17 Dec 2026 · Public review: 17–20 Dec 2026 · Prizes distributed within 14 working days after public review.

## Phase 1 — Contract (target: by 25 Nov 2026)

- [ ] Contract code complete: `checkIn()` (1×/day UTC, Agent ID `balanceOf > 0` gate), on-chain consecutive streaks, `claimBadge(7/14/30)` soulbound ERC-721 mint, emergency pause (owner-only, the only owner permission).
- [ ] Contract reviewed against the hackathon red lines: no user funds held (no deposits, no paid mints), no "Binance"/"BNB" naming in contract/token names, owner permissions documented.
- [ ] Deploy to BNB Chain mainnet.
- [ ] Record contract address: `TBD`
- [ ] Verify source code on BscScan and publish as open-source (required by the rules).
- [ ] Save the BscScan verified-source link.

## Phase 2 — Frontend

- [ ] Frontend built as a static site: connect via injected provider (MetaMask / Rabby / Binance Wallet), no QR login, no session storage, user confirms every transaction.
- [ ] Contract address wired into the frontend (replace placeholder with the deployed address).
- [ ] Deploy hosting; record live website URL: `TBD`
- [ ] GitHub repo public with full source (contract + frontend); record repo URL: `TBD`

## Phase 3 — End-to-End Test

- [ ] Real end-to-end test with an Agent ID holder wallet: connect → check in → confirm the transaction on-chain → verify streak increments → verify badge claim works at a milestone (or on test data).
- [ ] Verify a non-Agent-ID wallet is correctly rejected by `checkIn()`.
- [ ] Verify the leaderboard reads on-chain events correctly.
- [ ] Confirm no user funds are held and no transaction is ever sent without user confirmation.

## Phase 4 — Submit to Binance

- [ ] Fill in `SUBMISSION-DRAFT.md` with the real website URL, contract address, and GitHub repo URL.
- [ ] Reward receiving address: `TBD` — to be filled by the project lead (do not guess).
- [ ] Submit the project via the official Binance hackathon submission form before **9 Dec 2026 08:00 UTC**.
- [ ] Keep a screenshot / confirmation of the submission.

## Phase 5 — Promotion (30+ Agent ID users, organic only)

- [ ] Start posting on deploy day — see `PROMOTION-PLAN.md` for the drafted posts.
- [ ] Post on X (Rayan posts; drafts provided) with `#BinanceWalletHackathon` and `#AgenticWallet`.
- [ ] Post on Binance Square (draft provided).
- [ ] Share in Agent ID community groups.
- [ ] Post weekly streak updates (leaderboard highlights, milestone badges claimed).
- [ ] **Never** use fake accounts or fake interactions — that is disqualification. Organic growth only.

## Phase 6 — Monitor Metrics

- [ ] Track the number of unique Agent ID addresses that have interacted with the contract (Innovation Award minimum: **30**).
- [ ] Track transaction count and volume (Growth Award metrics).
- [ ] Track badge claims and leaderboard growth for weekly updates.
- [ ] Check metrics at least every 2–3 days; escalate to the team if the 30-address pace is behind schedule.

## Key Dates

| Date | Milestone |
|---|---|
| 18 Nov 2026 08:00 UTC | Submission window opens |
| **25 Nov 2026** | Internal deploy deadline (parent target) |
| 9 Dec 2026 08:00 UTC | Submission window closes |
| 9–17 Dec 2026 | Internal review |
| 17–20 Dec 2026 | Public review |
| ≤14 working days after public review | Prize distribution |
