# Factory Deploy — AgentStreak via canonical CREATE2 factory (EIP-7997)

> **Status: READY — simulation passed on a BSC mainnet fork. Nothing broadcast.**
> The parent runs the `baw` preview + Rayan's "Sudah" approval flow. This doc
> contains everything needed for that step. **Do NOT broadcast from here.**

## Why a factory?

The Binance Agentic Wallet CLI (`baw contract-call`) **cannot send contract
creation transactions** — `--to` is mandatory for EVM. The canonical Arachnid
CREATE2 factory (EIP-7997) is already deployed on BSC at the same address as
on every EVM chain, so the Agentic wallet deploys by making a normal contract
CALL to the factory with `calldata = salt (32 bytes) ++ init code`. The
factory then `CREATE2`s the contract. The factory's runtime code was verified
by the parent to match the EIP-7997 specification exactly (2 RPCs).

Because the deployer (`msg.sender` at construction) is the factory, the
contract owner is passed **explicitly** as a constructor argument — see
`src/AgentStreak.sol` (`constructor(address agentIdAddress, address ownerAddress)`).

## Deployment parameters (all computed programmatically — no hand-typed hex)

| | |
|---|---|
| Factory (Arachnid CREATE2, EIP-7997) | `0x4e59b44847b379578588920cA78FbF26c0B4956C` |
| Agent ID contract (constructor arg 1) | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |
| Owner (constructor arg 2) = deployer | `0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79` (Rayan's Agentic wallet) |
| Salt label | `agent-streak-v1` |
| Salt = keccak256("agent-streak-v1") | `0x2668b91ac7bc20e4d3adeca36a78ad24c26c1bccea650a22098a0f4db1ee8b07` |
| Init code | 7,037 bytes (creation bytecode ++ ABI-encoded constructor args) |
| Init code hash | `0x0037dfbb9df8c9aac011178b61c678b02df73116f87eb94e378e2300538b5954` |
| **Predicted CREATE2 address** | **`0x236C38Ea06D3151fEc3835EcC39F2874cC1996F1`** |
| Factory calldata (salt ++ init code) | 7,069 bytes |

Reproduce any of these with (no RPC, no key, no broadcast):

```bash
forge script script/BuildFactoryCalldata.s.sol
```

Cross-checks performed (all match):
- `cast keccak "agent-streak-v1"` == salt above.
- `cast create2 --salt <salt> --init-code $(cat factory-initcode.hex) --deployer <factory>` == predicted address above.
- `forge inspect AgentStreak bytecode` + `cast abi-encode "constructor(address,address)" <agentId> <owner>` == `factory-initcode.hex` byte-for-byte.

## Files

| File | Contents |
|---|---|
| `factory-initcode.hex` | `0x`-prefixed init code (7,037 bytes) |
| `factory-calldata.hex` | `0x`-prefixed factory calldata = salt ++ init code (7,069 bytes) — **this is the `--inputData` for the baw preview** |
| `script/BuildFactoryCalldata.s.sol` | Generates both files programmatically |
| `script/SimulateFactoryDeploy.s.sol` | Full fork simulation (below) |

The hex is deliberately kept in files, not pasted into chat/logs.

## Fork simulation (PASSED — BSC mainnet fork, 19 Nov 2026)

```bash
forge script script/SimulateFactoryDeploy.s.sol --fork-url https://bsc-dataseed.binance.org
```

Run against a live fork of BSC mainnet state (dry-run, nothing broadcast):

- Rayan's Agent ID `balanceOf` on the fork: **1** (real mainnet state).
- (a) Code deployed at the predicted address — **OK** (runtime size 6,756 bytes).
- (b) `owner()` == `0x3157…de79` — **OK**.
- (c) `agentId()` == `0x60B9…022F` — **OK**.
- (d) `checkIn()` from Rayan's wallet (a real Agent ID holder) — **OK**, streak 1, totalUsers 1.

## Gas + cost

Measured on the fork (internal factory-call gas) + computed tx overhead:

| Component | Gas |
|---|---|
| Factory call (internal, incl. CREATE2 + code deposit) | 1,560,813 |
| Tx base cost | 21,000 |
| Calldata (7,069 bytes: 6,834 non-zero × 16 + 235 zero × 4) | 110,284 |
| **Estimated total tx gas** | **1,692,097** |

| Gas price | Cost | Balance after (from 0.0016225 BNB) |
|---|---|---|
| 0.05 gwei (live at time of writing, 2 RPCs) | **0.0000846 BNB (~$0.049)** | ~0.00154 BNB |
| 0.1 gwei | 0.0001692 BNB | ~0.00145 BNB |
| 0.5 gwei | 0.0008460 BNB | ~0.00078 BNB |
| 1.0 gwei | 0.0016921 BNB | **INSUFFICIENT — exceeds balance** |

> ⚠️ **Break-even gas price ≈ 0.96 gwei.** Above it, the Agentic wallet
> (0.0016225 BNB) cannot afford this deploy. **Check the live gas price at
> preview time; only proceed at low gas (≤0.5 gwei is comfortable), or top
> the wallet up first.** The `baw` preview simulates the call — if its gas
> estimate differs materially from 1,692,097, STOP and re-check before
> executing.

## The baw preview command (parent runs this — NOT executed here)

```bash
cd ~/workspace/binance-agent-hackathon/contracts
baw contract-call preview \
  --binanceChainId 56 \
  --from 0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79 \
  --to 0x4e59b44847b379578588920cA78FbF26c0B4956C \
  --value 0 \
  --inputData $(cat factory-calldata.hex) \
  --json
```

One-line summary for Rayan's approval:
**BSC (56) · from 0x3157…de79 · to factory 0x4e59…4956C · asset BNB · amount 0 BNB · fee ~0.0000846 BNB (~$0.049 @ 0.05 gwei).**

After his "Sudah" (given AFTER this preview), execute with:

```bash
baw contract-call execute --requestId <id-from-preview> --json
```

## Pre-broadcast checklist (parent — re-verify at execution time)

1. Predicted address `0x236C38Ea06D3151fEc3835EcC39F2874cC1996F1` still has NO code on BSC (checked 19 Nov, 2 RPCs: empty). If it ever has code, STOP — the salt/init code pair was already used.
2. Live gas price ≤ 0.5 gwei (break-even ~0.96 gwei).
3. Agentic balance ≥ fee + a gas reserve (keep ≥0.001 BNB in the wallet).
4. `baw` preview simulation succeeds and its gas estimate is near 1,692,097.

## Post-deploy verification (read-only)

1. `eth_getCode(0x236C38Ea06D3151fEc3835EcC39F2874cC1996F1)` non-empty (2 RPCs).
2. `owner()` == `0x3157CccD41e37783b3Ee26678Eac32dd5d4ede79`; `agentId()` == `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`.
3. BscScan single-file verification (see DEPLOY.md; constructor args are now `(address,address)` — agentId, owner).
4. Fill `CONTRACT_ADDRESS` + `DEPLOY_BLOCK` in `frontend/config.js`, publish the repo + GitHub Pages, then submit the hackathon form.

## Test suite

`forge test` after the constructor change: **24/24 PASS** (the test deployer
passes `owner = address(this)` explicitly, so the pause tests are unchanged
in meaning). The fork simulation lives in `script/` and does not affect the
offline suite.
