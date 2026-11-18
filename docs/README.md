# Agent Streak — Frontend

Static dApp (HTML + CSS + vanilla JS, ethers.js v6 via CDN). No build step,
no backend, no server.

## Run locally

```bash
cd frontend
python3 -m http.server 8000
# open http://localhost:8000
```

> Must be served over HTTP — opening `index.html` directly from disk
> (`file://`) breaks ES module imports.

## Go live (after the contract is deployed)

1. Deploy `AgentStreak.sol` to BNB Chain (56).
2. In `config.js`, set `CONTRACT_ADDRESS` to the deployed address and
   `DEPLOY_BLOCK` to the deployment block number.
3. Replace the `GITHUB_REPO_URL` placeholder with the real repo URL.
4. Deploy the static site — see [HOSTING.md](./HOSTING.md) (recommended:
   GitHub Pages).

## Files

| File | Purpose |
|---|---|
| `index.html` | Page structure: header, Agent ID status, streak card, badges, leaderboard, footer |
| `style.css` | Dark theme, responsive, no framework |
| `app.js` | Wallet connect, Agent ID check, check-in, badge claims, leaderboard |
| `config.js` | Contract address (placeholder until deploy), ABI, RPCs, milestones |
| `HOSTING.md` | Hosting comparison + deploy plan (nothing deployed yet) |

## Behavior notes

- **No login session is stored.** The site only talks to the injected wallet
  (`window.ethereum`); every transaction is confirmed by the user in their
  own wallet.
- **Check-in requires an Agent ID** (ERC-721 balance > 0 on the Agent ID
  contract). Without one, the check-in button stays disabled.
- **One check-in per UTC day.** Streak state is read on-chain
  (`currentStreak` / `bestStreak` / `lastCheckInDay`).
- **Badges are soulbound** and read via `hasBadge(address, milestone)` for
  milestones 7 / 14 / 30 — the badge token is not enumerable.
- **Leaderboard** aggregates `CheckedIn` events via `eth_getLogs` from
  `DEPLOY_BLOCK`, best streak per address, top 20. Only addresses that have
  checked in appear (public on-chain data); there is no name-to-wallet
  search. If all public RPCs fail, the page says so honestly and offers a
  retry — no fake data is ever shown.
- While `CONTRACT_ADDRESS` is the zero address, the page runs in preview
  mode: wallet connect + Agent ID check work; check-in, badges and the
  leaderboard show a "not deployed yet" notice.
