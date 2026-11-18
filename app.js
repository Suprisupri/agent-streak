// Agent Streak — frontend logic (vanilla JS + ethers v6).
//
// Design notes:
// - No backend, no login session, no stored state. Every action is a wallet
//   transaction the user confirms in their own wallet.
// - Reads go through the injected provider when connected; the leaderboard
//   uses a public read-only RPC so it works before any wallet is connected.
// - Badge ownership is read via hasBadge(7/14/30) — the badge token is NOT
//   enumerable (no tokenOfOwnerByIndex).
// - The leaderboard only lists addresses that have emitted a CheckedIn event
//   (public on-chain data). There is no name-to-wallet search.

import { ethers } from "ethers";
import { CONFIG } from "./config.js";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const DAY_SECONDS = 86400;
const LEADERBOARD_CHUNK_BLOCKS = 5000; // eth_getLogs chunk size (keeps public RPCs happy)
const LEADERBOARD_TOP_N = 20;

const contractDeployed =
  CONFIG.CONTRACT_ADDRESS && CONFIG.CONTRACT_ADDRESS.toLowerCase() !== ZERO_ADDRESS;

// ---------------------------------------------------------------- state
let provider = null; // ethers.BrowserProvider (injected wallet)
let signer = null;
let account = null; // checksummed address or null
let chainId = null;
let agentIdOwned = false;
let isPaused = false;
let userStreak = { current: 0, best: 0, lastDay: 0, total: 0 };
let userBadges = {}; // milestone -> bool

// ---------------------------------------------------------------- helpers
const $ = (id) => document.getElementById(id);

const shortAddress = (addr) => `${addr.slice(0, 6)}…${addr.slice(-4)}`;

const todayDay = () => Math.floor(Date.now() / 1000 / DAY_SECONDS);

const bscscanTxUrl = (hash) => `${CONFIG.BSCSCAN_BASE}/tx/${hash}`;
const bscscanAddressUrl = (addr) => `${CONFIG.BSCSCAN_BASE}/address/${addr}`;

function setText(id, text) {
  const el = $(id);
  if (el) el.textContent = text;
}

function show(id, visible) {
  const el = $(id);
  if (el) el.classList.toggle("hidden", !visible);
}

function friendlyError(err) {
  if (!err) return "Unknown error.";
  if (err.code === 4001 || err.code === "ACTION_REJECTED") {
    return "Transaction rejected in your wallet. Nothing was sent.";
  }
  if (err.code === -32002) {
    return "A wallet request is already pending — please check your wallet.";
  }
  // Contract revert reasons surface as err.reason / err.shortMessage in ethers v6.
  const msg = err.shortMessage || err.reason || err.message || String(err);
  return msg.length > 200 ? `${msg.slice(0, 200)}…` : msg;
}

// ---------------------------------------------------------------- footer / static setup
function initStaticLinks() {
  const contractLink = $("footer-contract-link");
  if (contractDeployed) {
    contractLink.href = bscscanAddressUrl(CONFIG.CONTRACT_ADDRESS);
    contractLink.textContent = `Contract on BscScan (${shortAddress(CONFIG.CONTRACT_ADDRESS)})`;
  } else {
    contractLink.href = CONFIG.BSCSCAN_BASE;
    contractLink.textContent = "Contract on BscScan (not deployed yet)";
  }
  $("footer-github-link").href = CONFIG.GITHUB_REPO_URL;
  show("deploy-banner", !contractDeployed);
}

// ---------------------------------------------------------------- wallet connection
async function connectWallet() {
  if (!window.ethereum) {
    setText("agent-id-status", "No wallet detected. Install MetaMask, Rabby, or Binance Wallet, then reload this page.");
    return;
  }
  const btn = $("connect-btn");
  btn.disabled = true;
  btn.textContent = "Connecting…";
  try {
    provider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await provider.send("eth_requestAccounts", []);
    if (!accounts.length) throw new Error("No account returned by wallet.");
    signer = await provider.getSigner();
    account = await signer.getAddress();
    chainId = Number((await provider.getNetwork()).chainId);
    await refreshAll();
  } catch (err) {
    setText("agent-id-status", friendlyError(err));
    btn.disabled = false;
    btn.textContent = "Connect Wallet";
  }
}

async function switchToBnbChain() {
  if (!window.ethereum) return;
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: CONFIG.CHAIN_ID_HEX }],
    });
  } catch (err) {
    if (err.code === 4902) {
      // Chain not added to the wallet yet — ask the wallet to add it.
      try {
        await window.ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            {
              chainId: CONFIG.CHAIN_ID_HEX,
              chainName: CONFIG.CHAIN_NAME,
              nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
              rpcUrls: [CONFIG.READ_RPC_URLS[0]],
              blockExplorerUrls: [CONFIG.BSCSCAN_BASE],
            },
          ],
        });
      } catch (addErr) {
        setText("agent-id-status", friendlyError(addErr));
      }
    } else {
      setText("agent-id-status", friendlyError(err));
    }
  }
}

function renderChainIndicator() {
  const pill = $("chain-indicator");
  const switchBtn = $("switch-chain-btn");
  if (!account || chainId === null) {
    pill.textContent = "Not connected";
    pill.className = "pill pill-muted";
    show("switch-chain-btn", false);
    return;
  }
  if (chainId === CONFIG.CHAIN_ID) {
    pill.textContent = `● ${CONFIG.CHAIN_NAME} (56)`;
    pill.className = "pill pill-ok";
    show("switch-chain-btn", false);
  } else {
    pill.textContent = `● Wrong network (chain ${chainId})`;
    pill.className = "pill pill-warn";
    show("switch-chain-btn", true);
  }
}

function onWrongChain() {
  return account !== null && chainId !== null && chainId !== CONFIG.CHAIN_ID;
}

// ---------------------------------------------------------------- reads
function streakContract(readOnly = false) {
  const runner = readOnly || !signer ? provider : signer;
  return new ethers.Contract(CONFIG.CONTRACT_ADDRESS, CONFIG.AGENT_STREAK_ABI, runner);
}

function agentIdContract() {
  return new ethers.Contract(CONFIG.AGENT_ID_CONTRACT, CONFIG.AGENT_ID_ABI, provider);
}

async function loadUserData() {
  if (!account || !provider) return;

  // Agent ID ownership (independent of the AgentStreak contract).
  try {
    const balance = await agentIdContract().balanceOf(account);
    agentIdOwned = balance > 0n;
  } catch (err) {
    console.error("Agent ID balanceOf failed:", err);
    agentIdOwned = false;
    setText("agent-id-status", "Could not check your Agent ID (network error). Please refresh and try again.");
  }

  if (!contractDeployed) {
    renderAgentId();
    return;
  }

  const contract = streakContract(true);
  try {
    const [current, best, lastDay, total, totalUsers, totalGlobal, paused] =
      await Promise.all([
        contract.currentStreak(account),
        contract.bestStreak(account),
        contract.lastCheckInDay(account),
        contract.totalCheckIns(account),
        contract.totalUsers(),
        contract.totalCheckInsGlobal(),
        contract.paused(),
      ]);
    userStreak = {
      current: Number(current),
      best: Number(best),
      lastDay: Number(lastDay),
      total: Number(total),
    };
    isPaused = paused;
    setText("global-users", totalUsers.toString());
    setText("global-checkins", totalGlobal.toString());

    // Badge ownership: hasBadge per milestone (token is NOT enumerable).
    const owned = await Promise.all(
      CONFIG.BADGE_MILESTONES.map((m) => contract.hasBadge(account, m)),
    );
    userBadges = Object.fromEntries(CONFIG.BADGE_MILESTONES.map((m, i) => [m, owned[i]]));
  } catch (err) {
    console.error("Failed to load streak data:", err);
    setText("checkin-status", `Could not load your streak data: ${friendlyError(err)}`);
  }

  renderAgentId();
  renderStreak();
  renderBadges();
}

// ---------------------------------------------------------------- render: Agent ID
function renderAgentId() {
  const status = $("agent-id-status");
  const btn = $("connect-btn");
  if (!account) {
    status.textContent = "Connect your wallet to check your Agent ID.";
    show("agent-id-hint", false);
    show("wallet-address", false);
    btn.disabled = false;
    btn.textContent = "Connect Wallet";
    return;
  }
  btn.disabled = false;
  btn.textContent = `${shortAddress(account)} · Connected`;
  setText("wallet-address", `Connected wallet: ${account}`);
  show("wallet-address", true);

  if (agentIdOwned) {
    status.textContent = "Agent ID: Owned ✓ — you can check in.";
    status.className = "status-line status-ok";
    show("agent-id-hint", false);
  } else {
    status.textContent = "No Agent ID — check-in requires an Agent ID.";
    status.className = "status-line status-warn";
    show("agent-id-hint", true);
  }
}

// ---------------------------------------------------------------- render: streak
function renderStreak() {
  setText("stat-current", account && contractDeployed ? String(userStreak.current) : "—");
  setText("stat-best", account && contractDeployed ? String(userStreak.best) : "—");
  setText("stat-total", account && contractDeployed ? String(userStreak.total) : "—");

  const todayEl = $("stat-today");
  const btn = $("checkin-btn");
  const status = $("checkin-status");

  show("paused-banner", isPaused);

  if (!account) {
    todayEl.textContent = "—";
    btn.disabled = true;
    setText("checkin-status", "Connect your wallet to check in.");
    return;
  }
  if (!contractDeployed) {
    todayEl.textContent = "—";
    btn.disabled = true;
    setText("checkin-status", "Check-in activates once the contract is deployed.");
    return;
  }
  if (onWrongChain()) {
    todayEl.textContent = "—";
    btn.disabled = true;
    setText("checkin-status", `Switch to ${CONFIG.CHAIN_NAME} to check in.`);
    return;
  }
  if (isPaused) {
    todayEl.textContent = "—";
    btn.disabled = true;
    setText("checkin-status", "Check-ins are paused.");
    return;
  }
  if (!agentIdOwned) {
    todayEl.textContent = "—";
    btn.disabled = true;
    setText("checkin-status", "Check-in requires an Agent ID.");
    return;
  }

  const checkedInToday = userStreak.lastDay === todayDay();
  todayEl.textContent = checkedInToday ? "Checked in ✓" : "Not yet";
  todayEl.className = checkedInToday
    ? "stat-value stat-value-small status-ok"
    : "stat-value stat-value-small";
  btn.disabled = checkedInToday;
  if (checkedInToday) {
    setText("checkin-status", `Checked in today (UTC day ${todayDay()}). Come back tomorrow to keep your streak alive.`);
  } else {
    const atRisk =
      userStreak.current > 0 && userStreak.lastDay > 0 && userStreak.lastDay < todayDay() - 1;
    setText(
      "checkin-status",
      atRisk
        ? "Your streak has lapsed — check in today to start a new one."
        : "You have not checked in today yet.",
    );
  }
}

// ---------------------------------------------------------------- render: badges
function badgeStatus(milestone) {
  if (userBadges[milestone]) return "Owned";
  if (userStreak.current >= milestone) return "Claimable";
  return "Locked";
}

function renderBadges() {
  const list = $("badge-list");
  list.innerHTML = "";
  for (const milestone of CONFIG.BADGE_MILESTONES) {
    const status = account && contractDeployed ? badgeStatus(milestone) : "Locked";
    const card = document.createElement("div");
    card.className = `badge-card badge-${status.toLowerCase()}`;

    const icon = document.createElement("div");
    icon.className = "badge-icon";
    icon.textContent = status === "Owned" ? "🏅" : status === "Claimable" ? "🎖️" : "🔒";
    icon.setAttribute("aria-hidden", "true");

    const title = document.createElement("h3");
    title.textContent = `${milestone}-Day Streak`;

    const desc = document.createElement("p");
    desc.className = "muted small";
    desc.textContent =
      status === "Owned"
        ? "Claimed — this badge is soulbound to your wallet."
        : status === "Claimable"
          ? "Milestone reached — claim your soulbound badge."
          : `Reach a ${milestone}-day streak to unlock.`;

    const pill = document.createElement("span");
    pill.className = `pill ${status === "Owned" ? "pill-ok" : status === "Claimable" ? "pill-warn" : "pill-muted"}`;
    pill.textContent = status;

    const claimBtn = document.createElement("button");
    claimBtn.className = "btn btn-primary btn-small";
    claimBtn.textContent = "Claim Badge";
    claimBtn.disabled =
      status !== "Claimable" || !account || !contractDeployed || onWrongChain() || isPaused || !agentIdOwned;
    claimBtn.addEventListener("click", () => onClaimBadge(milestone, claimBtn));

    card.append(icon, title, desc, pill, claimBtn);
    list.appendChild(card);
  }
}

// ---------------------------------------------------------------- writes
async function onCheckIn() {
  const btn = $("checkin-btn");
  btn.disabled = true;
  setText("checkin-status", "Waiting for your confirmation in your wallet…");
  show("checkin-tx", false);
  try {
    const tx = await streakContract().checkIn();
    const link = $("checkin-tx-link");
    link.href = bscscanTxUrl(tx.hash);
    link.textContent = tx.hash;
    show("checkin-tx", true);
    setText("checkin-status", "Transaction sent — waiting for confirmation…");
    const receipt = await tx.wait();
    if (receipt.status === 1) {
      setText("checkin-status", "Checked in! Your streak is updated on-chain.");
      await refreshAll();
      await loadLeaderboard();
    } else {
      setText("checkin-status", "Transaction failed on-chain. No check-in was recorded.");
      btn.disabled = false;
    }
  } catch (err) {
    console.error("checkIn failed:", err);
    setText("checkin-status", friendlyError(err));
    btn.disabled = false;
  }
}

async function onClaimBadge(milestone, btn) {
  btn.disabled = true;
  setText("badge-status", `Claiming the ${milestone}-day badge — confirm in your wallet…`);
  try {
    const tx = await streakContract().claimBadge(milestone);
    setText("badge-status", "Transaction sent — waiting for confirmation…");
    const receipt = await tx.wait();
    if (receipt.status === 1) {
      setText(
        "badge-status",
        `Badge claimed! View the transaction on BscScan: ${bscscanTxUrl(tx.hash)}`,
      );
      await refreshAll();
    } else {
      setText("badge-status", "Transaction failed on-chain. The badge was not claimed.");
      btn.disabled = false;
    }
  } catch (err) {
    console.error("claimBadge failed:", err);
    setText("badge-status", friendlyError(err));
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------- leaderboard
async function loadLeaderboard() {
  const status = $("leaderboard-status");
  const table = $("leaderboard-table");
  const body = $("leaderboard-body");
  const retryBtn = $("leaderboard-retry-btn");
  const refreshBtn = $("leaderboard-refresh-btn");

  show("leaderboard-retry-btn", false);
  table.classList.add("hidden");
  body.innerHTML = "";
  refreshBtn.disabled = true;

  if (!contractDeployed) {
    setText("leaderboard-status", "The leaderboard activates once the contract is deployed.");
    refreshBtn.disabled = false;
    return;
  }

  setText("leaderboard-status", "Loading check-in events from the chain…");

  let lastError = null;
  for (const rpcUrl of CONFIG.READ_RPC_URLS) {
    try {
      const rpc = new ethers.JsonRpcProvider(rpcUrl);
      const contract = new ethers.Contract(CONFIG.CONTRACT_ADDRESS, CONFIG.AGENT_STREAK_ABI, rpc);
      const latest = await rpc.getBlockNumber();
      const fromBlock = Math.max(CONFIG.DEPLOY_BLOCK, 0);

      // Aggregate best streak per address from CheckedIn events.
      const bestByAddress = new Map();
      for (let start = fromBlock; start <= latest; start += LEADERBOARD_CHUNK_BLOCKS) {
        const end = Math.min(start + LEADERBOARD_CHUNK_BLOCKS - 1, latest);
        const events = await contract.queryFilter(contract.filters.CheckedIn(), start, end);
        for (const ev of events) {
          const addr = ev.args.user.toLowerCase();
          const streak = Number(ev.args.streak);
          if (streak > (bestByAddress.get(addr) ?? 0)) bestByAddress.set(addr, streak);
        }
      }

      const rows = [...bestByAddress.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, LEADERBOARD_TOP_N);

      if (rows.length === 0) {
        setText("leaderboard-status", "No check-ins yet — be the first!");
        refreshBtn.disabled = false;
        return;
      }

      for (const [i, [addr, streak]] of rows.entries()) {
        const tr = document.createElement("tr");
        if (account && addr === account.toLowerCase()) tr.className = "you-row";
        const rank = document.createElement("td");
        rank.textContent = String(i + 1);
        const addrCell = document.createElement("td");
        const link = document.createElement("a");
        link.href = bscscanAddressUrl(addr);
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        link.className = "mono";
        link.textContent = shortAddress(addr);
        addrCell.appendChild(link);
        if (account && addr === account.toLowerCase()) {
          const you = document.createElement("span");
          you.className = "pill pill-ok you-pill";
          you.textContent = "you";
          addrCell.appendChild(you);
        }
        const streakCell = document.createElement("td");
        streakCell.textContent = `${streak} days`;
        tr.append(rank, addrCell, streakCell);
        body.appendChild(tr);
      }

      table.classList.remove("hidden");
      setText(
        "leaderboard-status",
        `Top ${rows.length} of ${bestByAddress.size} addresses, scanned from block ${fromBlock.toLocaleString()} to ${latest.toLocaleString()}.`,
      );
      refreshBtn.disabled = false;
      return; // success — stop trying RPCs
    } catch (err) {
      console.error(`Leaderboard RPC failed (${rpcUrl}):`, err);
      lastError = err;
      // fall through to the next RPC
    }
  }

  // Every RPC failed — say so honestly, offer a retry.
  setText(
    "leaderboard-status",
    `Could not load the leaderboard: ${friendlyError(lastError)} The chain data is fine — this is a connection problem. Please try again.`,
  );
  show("leaderboard-retry-btn", true);
  refreshBtn.disabled = false;
}

// ---------------------------------------------------------------- refresh orchestration
async function refreshAll() {
  renderChainIndicator();
  renderAgentId();
  renderStreak();
  renderBadges();
  await loadUserData();
}

// ---------------------------------------------------------------- init
function init() {
  initStaticLinks();
  renderChainIndicator();
  renderAgentId();
  renderStreak();
  renderBadges();

  $("connect-btn").addEventListener("click", connectWallet);
  $("switch-chain-btn").addEventListener("click", switchToBnbChain);
  $("checkin-btn").addEventListener("click", onCheckIn);
  $("leaderboard-refresh-btn").addEventListener("click", loadLeaderboard);
  $("leaderboard-retry-btn").addEventListener("click", loadLeaderboard);

  // React to wallet-side changes (account / network switch).
  if (window.ethereum) {
    window.ethereum.on("accountsChanged", (accounts) => {
      if (!accounts.length) {
        account = null;
        signer = null;
        agentIdOwned = false;
        userStreak = { current: 0, best: 0, lastDay: 0, total: 0 };
        userBadges = {};
        refreshAll();
      } else {
        connectWallet();
      }
    });
    window.ethereum.on("chainChanged", () => {
      // Rebuild provider state on network change (standard practice).
      if (account) connectWallet();
      else renderChainIndicator();
    });
  }

  // Leaderboard loads immediately — it needs no wallet.
  loadLeaderboard();
}

document.addEventListener("DOMContentLoaded", init);
