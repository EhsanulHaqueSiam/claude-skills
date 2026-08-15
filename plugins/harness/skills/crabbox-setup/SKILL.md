---
name: crabbox-setup
description: Scaffold the crabbox ecosystem (.crabbox.yaml, setup.sh, cbx.sh, playwright config) into a repo, targeting the Hetzner VPS via static SSH instead of Daytona. Use when Siam wants a project's builds/tests/e2e running on the tuiber box.
---

# crabbox-setup — the loop-engineer box, on the Hetzner VPS

Port of the ai-builder-club `crabbox-setup` skill from Daytona to a **static SSH
box**: `46.62.232.186` (the tuiber/Dokploy host). Same scaffolded files, same
`cbx.sh` interface — so the rest of the plugin ecosystem (`/skills:new-loop`
etc., anything that calls `bash cbx.sh …`) composes unchanged. What's different:

| Daytona | This box |
|---|---|
| Snapshot + `devbox/Dockerfile` | One-time `host-prep.sh` (already applied) — tools persist |
| 60s exec cap → bg+poll hacks | No cap — `cbx.sh up` runs setup synchronously |
| docker-in-docker, pin 27.0.3 | **Rootless docker** (crabbox user's own daemon) — no pin |
| Box destroyed on `down` | Box persists; `down` stops this repo's processes only |
| Preview URLs unavailable | `cbx.sh tunnel` via plain ssh alias `crabbox` |

**Safety model (do not weaken):** the `crabbox` user has **no sudo and no access
to the root Docker daemon** where Dokploy production (tuiber.com) runs. Its
rootless dockerd, files, and processes all live under `/home/crabbox/`. Never
scaffold anything that needs root on the box; surface the need to Siam instead.

You are SCAFFOLDING files into the target repo. Templates live in `assets/`
(next to this skill); copy them in and ADAPT (every one has `# EDIT:` markers).

## Step 0 — Discover (reuse dev-local, don't re-derive)
If `scripts/dev-local.sh` exists, read it: it already encodes services, ports,
infra deps, start commands. `setup.sh` should mirror it. Otherwise discover:
package manager, dev cmd + **port**, backing services, secret var names.
Decide: needs containers? (compose/postgres/redis → keep docker block) —
browser e2e? (keep playwright config) — secrets? (→ `env.allow`, never sync).

## Step 1 — box prerequisites (usually already done)
The tuiber box is prepped: node 24 + pnpm (mise), rootless docker, Chrome 151,
`@playwright/cli`, `ssh` alias `crabbox`. For a NEW box, run
`assets/host-prep.sh` as root there, then add an ssh alias.
A repo needing another tool: `ssh crabbox 'mise use -g bun@latest'` (persists;
repos with `.mise.toml`/`.nvmrc` are picked up per-directory automatically).

## Step 2 — `.crabbox.yaml`
Copy `assets/crabbox.yaml` → repo root as `.crabbox.yaml`. Set `sync.exclude`
(deps/build dirs + `**/.env*`) and `env.allow` (exact secret var names —
forwarded over SSH from the local shell, never synced, never in git).
The repo yaml holds NO host or key: crabbox refuses repo-configured SSH hosts
(a cloned repo must not point your key anywhere). Box identity + `ssh.key` live
in `~/.config/crabbox/config.yaml` (already set on the laptop), and `cbx.sh`
exports `CRABBOX_STATIC_HOST` as the explicit approval.

## Step 3 — `setup.sh` (boots the stack on the box AND locally)
Copy `assets/setup.sh`; adapt the EDIT block (install/dev/migrate cmds, port,
services). **Pick an APP_PORT unique to this project** — the box is shared and
two repos on :3000 collide. Idempotent (check-before-act), so `bash setup.sh`
also works locally. Ends with `STACK READY`. Containers must be started with
`docker compose -p "$REPO"` so `cbx.sh down` can clean this project only.

## Step 4 — `cbx.sh` + browser config
Copy `assets/cbx.sh`; set the config block (APP_PORT, TUNNEL_PORTS). Interface:
```sh
bash cbx.sh up   <name>            # sync + setup.sh → STACK READY
bash cbx.sh logs <name>            # tail setup/dev logs
bash cbx.sh tunnel <name> &        # localhost → box (see it in YOUR browser)
bash cbx.sh pw   <name> -- <args>  # playwright-cli IN the box (drives the app)
bash cbx.sh get  <name> <remote> <local>   # pull screenshot/video off the box
bash cbx.sh down <name>            # stop THIS repo's dev server + containers
```
If browser e2e: copy `assets/cli.config.json` → `.playwright/cli.config.json`
(chrome channel + `--no-sandbox`; keep it tracked).

## Step 5 — gitignore + commit (required for fast sync)
Add: `evidence`, `.crabbox`, `.cbx-*.id`, `.cbx-*.sandbox`, `.playwright-cli`.
Then **commit** — crabbox only skips re-uploading when the tree matches HEAD
(clean tree ≈ 1s sync; dirty ≈ 15–20s).

## Step 6 — Verify
```sh
bash cbx.sh up demo                          # → ✓ STACK READY
bash cbx.sh pw demo -- open http://localhost:<APP_PORT>   # smoke
bash cbx.sh get demo /tmp/<artifact> evidence/<artifact>  # pull proof
bash cbx.sh down demo
```
Parallel loops = multiple repos side by side on the box (16 cores / 30 GB),
each in its own workdir `~/work/static_46-62-232-186/<repo>/` with its own
APP_PORT and compose project. Same-repo parallel variants need a worktree
clone (distinct dir name) — one workdir per repo name.

## Gotchas
- **Never bind public ports on the box** — it serves tuiber.com production.
  Everything stays on the box's localhost; reach it via `cbx.sh tunnel`.
- **`down` ≠ wipe.** Files persist for fast re-sync. Reclaim ONE repo:
  `ssh crabbox 'rm -rf ~/work/static_46-62-232-186/<repo>'`. Never delete
  `~/work` wholesale or touch anything outside `/home/crabbox/`.
- **Rootless docker limits:** can't bind ports <1024 (fine — dev ports), no
  root Docker daemon access (deliberate). testcontainers etc. work via
  `DOCKER_HOST` (already exported in the crabbox user's `.bashrc`).
- fail2ban on the box: 6 failed SSH auths in 5 min = 1h full-IP ban. Key
  problems → fix locally, don't retry in a loop.
- Occasional `warning: egress remote client cleanup failed … exit status 255`
  after a run is cosmetic; the run's own exit code is what counts.
- ssh aliases: `crabbox` (runner), `veritas`/`tuiber` (lcteam admin),
  `tuiber-root` (password-only root).
