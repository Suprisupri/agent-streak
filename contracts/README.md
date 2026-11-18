# Agent Streak — Contracts

Daily check-in dApp for Binance Agent ID holders on BNB Chain (chain 56).
Users with an Agent ID check in once per UTC day, build a streak, and claim
soulbound ERC-721 badges at 7 / 14 / 30-day milestones.

**Hackathon:** Binance Agent ID hackathon.
**Chain:** BNB Chain mainnet (56). **Solidity:** ^0.8.24. **Framework:** Foundry.
**Agent ID contract:** `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (SPACE ID Agent ID, ERC-721, non-transferable). Ownership is checked via `balanceOf(address) > 0`.

## Layout

| Path | What it is |
|---|---|
| `src/AgentStreak.sol` | The only contract (dependency-free: no external imports, so BscScan verification is trivial) |
| `test/AgentStreak.t.sol` | 24 Foundry tests incl. a minimal mock Agent ID contract |
| `script/Deploy.s.sol` | Deploy script — **dry-run only by default, never broadcasts without `--broadcast`** |
| `DEPLOY.md` | Gas estimate, deploy cost, and BscScan verification steps |

## Build & test

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge build
forge test            # 24 tests, 0 failures
forge test --gas-report
```

## Functions

### User functions

| Function | Description |
|---|---|
| `checkIn()` | Check in for the current UTC day (`day = block.timestamp / 86400`). Requires holding an Agent ID (`NotAgentIdHolder` otherwise). One check-in per day per address (`AlreadyCheckedIn`). Consecutive day → streak +1; gap → streak resets to 1. Updates `bestStreak`. Emits `CheckedIn(user, day, streak)`. |
| `claimBadge(uint256 milestone)` | Mint a soulbound badge for milestone `7`, `14`, or `30` (other values revert `InvalidMilestone`). Requires `bestStreak >= milestone` (`InsufficientStreak`) and one badge per milestone per address (`BadgeAlreadyClaimed`). Returns the new `tokenId`. Emits `BadgeClaimed(user, milestone, tokenId)`. |

### Views

| Function | Description |
|---|---|
| `currentStreak(address)` | Current consecutive-day streak |
| `bestStreak(address)` | All-time best streak |
| `lastCheckInDay(address)` | UTC day index of the last check-in |
| `totalCheckIns(address)` | Total check-ins by an address |
| `hasBadge(address, milestone)` | Whether an address claimed a milestone badge |
| `totalUsers` | Number of unique addresses that ever checked in |
| `totalCheckInsGlobal` | Total check-ins across all users |
| `badgeMilestone(tokenId)` | Milestone of a badge token |
| `tokenURI(tokenId)` | On-chain JSON metadata (base64 data URI) with an on-chain SVG image |

### Badge (soulbound ERC-721)

- `name` = "Agent Streak Badge", `symbol` = "ASB". Minimal ERC-721 implementation (no imports): `balanceOf`, `ownerOf`, `tokenURI`, `supportsInterface` (ERC-165 / ERC-721 / ERC-721-Metadata).
- **Soulbound:** `transferFrom`, both `safeTransferFrom` overloads, `approve`, and `setApprovalForAll` all revert with `Soulbound`. `getApproved` returns `address(0)`, `isApprovedForAll` returns `false`.
- `tokenURI` returns a `data:application/json;base64,` URI. JSON contains `name` ("Agent Streak Badge — 7 Days", etc.), `description`, `image` (on-chain SVG, base64), and `attributes` (Milestone, Streak Days, Soulbound = "Yes"). No external metadata dependency.

## Owner Permissions

**The owner can do exactly one thing: pause and unpause the contract.**

| Function | Who | Effect |
|---|---|---|
| `pause()` | owner only | Stops `checkIn()` and `claimBadge()` (both revert `ContractPaused`). Views keep working. |
| `unpause()` | owner only | Resumes `checkIn()` and `claimBadge()`. |

The owner is set once in the constructor (explicit `ownerAddress` argument, immutable) and **cannot be changed**. It is passed explicitly — not taken from `msg.sender` — because the production deploy goes through a CREATE2 factory (see FACTORY-DEPLOY.md), where `msg.sender` at construction is the factory.

Explicitly, the contract has **none** of the following:

- **No funds custody.** There is no payable function except a `receive()` that reverts — the contract cannot accept BNB. It never holds user funds.
- **No withdraw.** There is no withdraw function of any kind (nothing to withdraw).
- **No forced mint.** Badges can only be minted by a user calling `claimBadge()` for themselves after earning the streak. The owner cannot mint, burn, or transfer badges.
- **No rule changes.** Streak rules, milestones (7/14/30), and the Agent ID contract address are fixed at deploy time. There is no setter for any of them.
- **No fee, no deposit, no paid mint.** Check-ins and badge claims cost only gas.

## Errors

`NotAgentIdHolder`, `AlreadyCheckedIn`, `InvalidMilestone`, `InsufficientStreak`, `BadgeAlreadyClaimed`, `Soulbound`, `ContractPaused`, `NotOwner`, `TokenDoesNotExist`.

## Deploy

See [DEPLOY.md](DEPLOY.md). **Do not deploy without the project owner's explicit approval.** The deploy script never broadcasts unless invoked with `--broadcast`.
