# Agent Streak — Deploy Guide

> **STATUS: NOT DEPLOYED.** This document only prepares the deployment.
> Broadcasting to BSC mainnet or testnet requires the project owner's
> explicit approval. The deploy script never broadcasts without `--broadcast`.

## Contract

- **Source:** `src/AgentStreak.sol` (single file, no imports — trivial BscScan verification)
- **Compiler:** solc 0.8.24, optimizer on, 200 runs
- **Constructor arg:** Agent ID contract `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- **Deployed size:** 6,959 bytes (well under the 24,576-byte limit)

## Gas estimate (measured, not guessed)

Deployment gas was measured by actually deploying to a local anvil node
(`forge script --broadcast` against anvil, chain 31337, run artifact in
`broadcast/Deploy.s.sol/31337/`). It matches `forge test --gas-report`
exactly.

| Item | Gas |
|---|---|
| Deployment | **1,537,312** |
| `checkIn()` first time (cold storage) | 164,407 |
| `checkIn()` typical (warm) | ~56,869 |
| `claimBadge()` | ~86,178 avg / 123,900 max |
| `pause()` / `unpause()` | ~44,580 / ~24,415 |

## Deploy cost

Measured 2026-11-18 ~18:14 UTC (01:14 WIB 19 Nov):

- BSC gas price (live, `cast gas-price`, `https://bsc-dataseed.binance.org`): **0.05 gwei** (50,000,000 wei)
- BNB price (CoinGecko, same time): **$582.37**

| Scenario | Gas price | Cost (BNB) | Cost (USD) |
|---|---|---|---|
| At current gas price | 0.05 gwei | **0.0000768656 BNB** | **~$0.045** |
| Conservative (gas spike) | 1 gwei | 0.0015373120 BNB | ~$0.90 |

Gas price fluctuates — re-check with `cast gas-price --rpc-url https://bsc-dataseed.binance.org` right before deploying.

**One-line summary (for approval):**
BSC mainnet (56) · from 0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79 · to (new AgentStreak contract, address TBD at deploy) · asset BNB · amount 0 BNB · fee ~0.0000769 BNB (~$0.045 at 0.05 gwei; up to ~0.00154 BNB / ~$0.90 at 1 gwei).

## Deploy steps (owner approval required)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd ~/workspace/binance-agent-hackathon/contracts

# 1. Dry-run first (no broadcast, no key needed):
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org

# 2. Broadcast (ONLY with owner approval; key via env, never in chat):
forge script script/Deploy.s.sol \
  --rpc-url https://bsc-dataseed.binance.org \
  --broadcast --private-key "$PRIVATE_KEY"

# 3. Note the deployed address from the output / broadcast/Deploy.s.sol/56/run-latest.json
```

## BscScan verification

The contract has **zero imports**, so verification is a single-file submission:

```bash
forge verify-contract <DEPLOYED_ADDRESS> src/AgentStreak.sol:AgentStreak \
  --chain 56 \
  --constructor-args $(cast abi-encode "constructor(address,address)" 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F 0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79) \
  --compiler-version 0.8.24 \
  --optimizer-runs 200 \
  --etherscan-api-key "$BSCSCAN_API_KEY"
```

Or verify in one step at deploy time by adding `--verify` to the broadcast command above (needs `BSCSCAN_API_KEY` set).

After verification, confirm on BscScan that:
- the source matches `src/AgentStreak.sol` exactly,
- the constructor arguments decode to the Agent ID address above and the owner address 0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79,
- the "Read Contract" tab shows `agentId = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` and `owner = 0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79`.

## Post-deploy sanity checks (read-only)

```bash
cast call <DEPLOYED_ADDRESS> "agentId()(address)" --rpc-url https://bsc-dataseed.binance.org
cast call <DEPLOYED_ADDRESS> "owner()(address)"   --rpc-url https://bsc-dataseed.binance.org
cast call <DEPLOYED_ADDRESS> "paused()(bool)"     --rpc-url https://bsc-dataseed.binance.org
```
