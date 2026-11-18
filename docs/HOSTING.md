# Hosting Plan — Agent Streak (static site)

> **Status: plan only — nothing has been deployed.** Deployment happens later,
> by the parent agent, after approval.

The frontend is a purely static site (`index.html` + `style.css` + `app.js` +
`config.js`, ethers.js v6 loaded from a CDN). No build step, no backend, no
server-side code — any static host works. The two realistic options:

## Comparison

| | GitHub Pages | Cloudflare Pages |
|---|---|---|
| **Cost** | Free (public repo) | Free (generous limits) |
| **Deploy source** | Directly from the GitHub repo (branch/folder) | Connects to the GitHub repo, deploys on push |
| **Setup effort** | Lowest — one toggle in repo Settings, no extra account/service beyond GitHub | Low, but needs a Cloudflare account + connecting the repo + a project config |
| **Custom domain** | Supported, free HTTPS (Let's Encrypt) | Supported, free HTTPS, more DNS control |
| **Build step** | None needed (can deploy a folder as-is) | None needed (set build command empty, output dir `frontend/`) |
| **HTTPS** | Yes, automatic | Yes, automatic |
| **Preview deploys per PR** | No (only one live branch) | Yes, automatic per pull request |
| **Bandwidth / limits** | 100 GB/month soft limit, 1 GB site size — plenty for this | Unlimited bandwidth on free tier |
| **Fit with open-source verification** | Ideal — the live site *is* the public repo; judges can diff site vs. source in one place | Good, but the live site is one indirection away from the repo |

## Recommendation: GitHub Pages

**GitHub Pages is the simplest choice**, and it fits this project best:

1. The hackathon requires a **public GitHub repo** for open-source verification
   anyway — GitHub Pages deploys from that same repo, so there is exactly one
   place to look at (code + live site).
2. Zero extra accounts or services: one toggle in repo Settings, no build
   config, no DNS wrangling to get started.
3. The site is tiny (a few KB of HTML/CSS/JS); Pages' limits are irrelevant.
4. Cloudflare Pages' advantages (preview deploys, unlimited bandwidth) don't
   matter for a 4-file static site with no PR workflow.

Cloudflare Pages remains a fine fallback if custom-domain/DNS needs grow later
— migrating is just pointing Cloudflare at the same repo.

## Deploy steps (to run after approval)

Prerequisites: the public repo exists (see structure below) and
`config.js` has the real `CONTRACT_ADDRESS` + `DEPLOY_BLOCK` filled in.

1. Push the repo to GitHub (public).
2. Repo → **Settings → Pages**.
3. Under **Build and deployment → Source**, choose **Deploy from a branch**.
4. Branch: `main`, folder: `/frontend` (or `/ (root)` if the repo is
   frontend-only — see structure note below). Save.
5. Wait ~1 minute. The site goes live at
   `https://<username>.github.io/<repo>/`.
6. Verify: open the URL, confirm the page renders, connect a wallet, confirm
   the Agent ID check and leaderboard load.
7. (Optional, later) Custom domain: add a `CNAME` file with the domain in
   `frontend/`, then set the domain in Settings → Pages and point DNS
   (CNAME → `<username>.github.io`).

Every later push to `main` redeploys automatically.

## Suggested repo structure (one public repo, contracts + frontend)

The hackathon asks for open-source verification, so keep everything in **one
public repo** — judges and users verify contract + frontend together:

```
agent-streak/
├── README.md                  # project overview, how to run, contract addresses
├── LICENSE                    # e.g. MIT
├── contracts/
│   ├── AgentStreak.sol        # check-in + streak + soulbound badges
│   └── ...                    # deploy scripts, tests
├── frontend/
│   ├── index.html
│   ├── style.css
│   ├── app.js
│   ├── config.js              # CONTRACT_ADDRESS + DEPLOY_BLOCK (filled post-deploy)
│   ├── HOSTING.md             # this file
│   └── README.md              # local dev instructions
└── docs/                      # hackathon submission notes, architecture diagram
```

Notes:
- The local workspace already mirrors this layout
  (`~/workspace/binance-agent-hackathon/{contracts,frontend,scripts,docs}/`).
- `config.js` contains only public data (contract addresses, RPC URLs) — safe
  to commit. Never commit private keys, deployer mnemonics, or `.env` files.
- If GitHub Pages is configured with folder `/frontend`, the live site root is
  the `frontend/` directory — relative asset paths (`./style.css`, `./app.js`)
  already assume this and work identically when served from a subpath.
