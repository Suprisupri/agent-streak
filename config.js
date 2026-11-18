// Agent Streak — frontend configuration.
//
// HOW TO GO LIVE:
//   1. Deploy AgentStreak.sol to BNB Chain (chain id 56).
//   2. Paste the deployed contract address into CONTRACT_ADDRESS below.
//   3. Set DEPLOY_BLOCK to the block number of the deployment transaction
//      (the leaderboard scans CheckedIn events starting from this block).
//   4. Replace GITHUB_REPO_URL with the real public repo URL.
// No other code changes are needed — the app works fully once these are set.

export const CONFIG = {
  // Deployed 19 Nov 2026 ~02:07 WIB (block 134364540, tx 0x24a006d5…b3c58).
  CONTRACT_ADDRESS: "0x236C38Ea06D3151fEc3835EcC39F2874cC1996F1",

  // Block number of the deployment transaction.
  DEPLOY_BLOCK: 134364540,

  // Agent ID (ERC-721) — read-only. Ownership is checked via balanceOf > 0.
  AGENT_ID_CONTRACT: "0x60b9262456de011f7d15a54cdd8c48baaa8b022f",

  // BNB Chain mainnet.
  CHAIN_ID: 56,
  CHAIN_ID_HEX: "0x38",
  CHAIN_NAME: "BNB Chain",

  // Public read-only RPC endpoints used for the leaderboard (works before
  // any wallet is connected). Tried in order; the first healthy one wins.
  READ_RPC_URLS: [
    "https://bsc.publicnode.com",
    "https://bsc-dataseed1.defibit.io",
    "https://bsc-dataseed1.ninicoin.io",
  ],

  // Block explorer base URL (used for tx + contract links).
  BSCSCAN_BASE: "https://bscscan.com",

  // Public repo URL.
  GITHUB_REPO_URL: "https://github.com/Suprisupri/agent-streak",

  // Badge milestones (consecutive-day streaks).
  BADGE_MILESTONES: [7, 14, 30],

  // AgentStreak contract ABI (human-readable fragments, ethers v6).
  AGENT_STREAK_ABI: [
    // Writes
    "function checkIn()",
    "function claimBadge(uint256 milestone)",
    // Views
    "function currentStreak(address) view returns (uint256)",
    "function bestStreak(address) view returns (uint256)",
    "function lastCheckInDay(address) view returns (uint256)",
    "function totalCheckIns(address) view returns (uint256)",
    "function hasBadge(address, uint256) view returns (bool)",
    "function totalUsers() view returns (uint256)",
    "function totalCheckInsGlobal() view returns (uint256)",
    "function paused() view returns (bool)",
    // Badge ERC-721 (NOT enumerable — no tokenOfOwnerByIndex;
    // badge ownership is read via hasBadge for 7 / 14 / 30)
    "function balanceOf(address) view returns (uint256)",
    "function tokenURI(uint256) view returns (string)",
    // Events
    "event CheckedIn(address indexed user, uint256 day, uint256 streak)",
    "event BadgeClaimed(address indexed user, uint256 milestone, uint256 tokenId)",
  ],

  // Agent ID contract ABI (only what we need: ownership check).
  AGENT_ID_ABI: [
    "function balanceOf(address owner) view returns (uint256)",
  ],
};
