# Agent Streak

Daily check-in for Agent ID holders — build your streak, earn soulbound badges, prove you're here to stay.

Built for the **Binance Agent ID Hackathon** (BNB Chain). Live at: **https://suprisupri.github.io/agent-streak/**

## What it is

Holders of a Binance Agent ID check in once per day (UTC) by calling `checkIn()` on the smart contract. Consecutive check-ins build an on-chain streak. At streak milestones of **7, 14, and 30 days**, holders can claim soulbound ERC-721 badges — non-transferable proof of consistency tied to their Agent ID holder address. A public leaderboard, built from on-chain events, ranks the most consistent agents.

No deposits, no paid mints, no funds held: the only cost is gas.

## How Agent ID is used

1. **Gating.** `checkIn()` reverts unless the caller's Agent ID balance is greater than zero (`balanceOf > 0`). Non-holders cannot check in, build a streak, or claim badges.
2. **Streak identity.** Each streak is recorded per Agent ID holder address — a portable, public, on-chain reputation of consistency.
3. **Soulbound badges bound to Agent ID holders.** `claimBadge(7 / 14 / 30)` mints a non-transferable ERC-721 badge only to Agent ID holders who reached the milestone.
4. **Leaderboard of agents.** Ranked from on-chain events — a public, verifiable ranking of the most consistent agents.

## Contract (BNB Chain mainnet)

| | |
|---|---|
| AgentStreak | [`0x236C38Ea06D3151fEc3835EcC39F2874cC1996F1`](https://bscscan.com/address/0x236C38Ea06D3151fEc3835EcC39F2874cC1996F1) |
| Agent ID (SPACE ID) | [`0x60b9262456de011f7d15a54cdd8c48baaa8b022f`](https://bscscan.com/address/0x60b9262456de011f7d15a54cdd8c48baaa8b022f) |
| Deployed | Block 134364540 · [tx](https://bscscan.com/tx/0x24a006d51495c0a13460cc1cfc6ace4b05b4d9c028141105d9360662e4bb3c58) |
| Source | Verified on BscScan (Exact Match) · Solidity 0.8.24 · MIT · optimizer 200 runs |

Owner permissions are minimal: the owner can only pause / unpause check-ins and badge claims. There is no withdraw, no forced mint, no streak-rule change. The contract rejects BNB transfers (`receive()` reverts).

## Repo layout

```
├── index.html / style.css / app.js / config.js   # static dApp (GitHub Pages)
├── contracts/
│   ├── AgentStreak.sol                            # the contract (zero imports)
│   ├── AgentStreak.t.sol                          # Foundry tests (24/24 pass)
│   ├── Deploy.s.sol                               # deploy script
│   └── foundry.toml
└── docs/                                          # hackathon submission notes
```

## Run the dApp locally

```bash
python3 -m http.server 8000
# open http://localhost:8000 — connect MetaMask / Rabby / Binance Wallet on BNB Chain
```

## Run the tests

```bash
cd contracts && forge test   # 24 tests, all passing
```

## Deploy notes

The contract was deployed via the canonical CREATE2 factory (`0x4e59b44847b379578588920cA78FbF26c0B4956C`) because the deployer wallet signs through the Binance Agentic Wallet CLI, which only supports contract calls (no contract creation). See `contracts/FACTORY-DEPLOY.md` for the full procedure.

## Disclaimer

This project is not affiliated with or endorsed by Binance. "Binance Agent ID Hackathon" is referenced only as the name of the event this project is submitted to. No returns, rewards, or earnings are promised to users.

## License

MIT
