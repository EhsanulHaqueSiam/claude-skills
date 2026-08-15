---
name: crabbox-setup
description: Scaffold the crabbox ecosystem (.crabbox.yaml, setup.sh, cbx.sh, playwright config) into a repo, targeting YOUR VPS via static SSH instead of Daytona. Asks for the box details (host, ssh user/alias) on first use. Use when builds/tests/e2e should run on a persistent cloud box.
---

# crabbox-setup — the loop-engineer box, on a static-SSH VPS

Port of the Daytona-based crabbox skill to a **persistent static-SSH box** (any
VPS — Hetzner, AWS, etc.). Same scaffolded files, same `cbx.sh` interface — so
the sibling harness skills (`verifier-setup`, `new-loop`, anything that calls
`bash cbx.sh …`) compose unchanged. What's different:

| Daytona | Static box |
|---|---|
| Snapshot + `devbox/Dockerfile` | One-time `assets/host-prep.sh` — tools persist |
| 60s exec cap → bg+poll hacks | No cap — `cbx.sh up` runs setup synchronously |
| docker-in-docker, pin 27.0.3 | **Rootless docker** (runner user's own daemon) — no pin |
| Box destroyed on `down` | Box persists; `down` stops this repo's processes only |
| Preview URLs unavailable | `cbx.sh tunnel` via a plain ssh alias |

**Safety model (do not weaken):** the runner user has **no sudo and no access
to the root Docker daemon**. Its rootless dockerd, files, and processes all live
under its own home dir, so nothing else on the box is reachable. Never scaffold
anything that needs root on the box; surface the need to the user instead.

You are SCAFFOLDING files into the target repo. Templates live in `assets/`
(next to this skill); copy them in and ADAPT (every one has `# EDIT:` markers).

## Step 0 — Box bootstrap (AUTOMATIC and idempotent — run it every time)

This skill ships with NO box baked in, and YOU do the setup — the user answers
questions once; every later run re-checks and repairs instead of re-asking.

**0a. Load or ask the config (once).** If `~/.config/crabbox/config.yaml` has a
`static.host`, use it and skip the questions. Otherwise ask the user for:
- **VPS IP/hostname**
- **their GitHub username** (whose public keys `ssh-import-id` will authorize)
- runner user (default `crabbox`) and ssh alias (default `crabbox`) — only ask
  if they want non-defaults.

**0b. Laptop CLI.** `crabbox --version` — if missing, install the matching
binary from github.com/openclaw/crabbox releases into `~/.local/bin`
(checksum-verify against `checksums.txt`).

**0c. Probe the box.** `ssh -o BatchMode=yes <runner>@<host> 'node --version;
docker info -f ok; command -v playwright-cli'` — if all pass, the box is
prepped: skip to 0e.

**0d. Prep the box (first time only).** Root access is needed once — ask the
user how they reach root (root password, an existing sudo user, or their cloud
console). Then copy `assets/host-prep.sh` to the box and run it as root with
the GitHub username as its argument. It is idempotent and does ALL of:
runner user creation (no sudo, no docker group) + key import from
`github.com/<user>.keys` + sshd `AllowUsers` handling + git/rsync/tar +
rootless docker (docker-ce-rootless-extras, linger, systemd --user service) +
Google Chrome + mise with node/pnpm + `@playwright/cli`. Re-run it any time —
it only creates what's missing.

**0e. Wire the laptop (idempotent).** Without clobbering existing entries:
- append an alias block to `~/.ssh/config`:
  `Host <alias> / HostName <host> / User <runner> / IdentityFile ~/.ssh/id_ed25519 / IdentitiesOnly yes`
- write `~/.config/crabbox/config.yaml` (box identity MUST live here, not in
  the repo yaml — crabbox refuses repo-configured SSH hosts so a cloned repo
  can't point your key at a stranger's box):
  ```yaml
  provider: ssh
  target: linux
  static: { host: <BOX_IP>, user: <runner>, port: "22", workRoot: /home/<runner>/work }
  ssh: { key: ~/.ssh/id_ed25519 }
  ```

**0f. Verify end-to-end** before touching the repo: `crabbox doctor --provider
ssh`, then `ssh <alias> 'docker run --rm hello-world'`. Fail loudly with what's
missing — never scaffold a repo against an unverified box.

## Step 1 — Discover the repo (reuse dev-local, don't re-derive)
If `scripts/dev-local.sh` exists, read it: it already encodes services, ports,
infra deps, start commands. `setup.sh` should mirror it. Otherwise discover:
package manager, dev cmd + **port**, backing services, secret var names.

## Step 2 — `.crabbox.yaml`
Copy `assets/crabbox.yaml` → repo root as `.crabbox.yaml`. Set `sync.exclude`
(deps/build dirs + `**/.env*`) and `env.allow` (exact secret var names —
forwarded over SSH from the local shell, never synced, never in git). No host
or key goes in this file (see Step 0).

## Step 3 — `setup.sh` (boots the stack on the box AND locally)
Copy `assets/setup.sh`; adapt the EDIT block (install/dev/migrate cmds, port,
services). **Pick an APP_PORT unique per project** — the box is shared and two
repos on the same port collide. Idempotent (check-before-act), so `bash setup.sh`
also works locally. Ends with `STACK READY`. Containers must start with
`docker compose -p "$REPO"` so `cbx.sh down` can clean this project only.

## Step 4 — `cbx.sh` + browser config
Copy `assets/cbx.sh`; fill its EDIT block (BOX_HOST, SSH_ALIAS, APP_PORT,
TUNNEL_PORTS). Interface (identical to the Daytona version):
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
Parallel loops = multiple repos side by side on the box, each in its own
workdir `~/work/static_<host-with-dashes>/<repo>/` with its own APP_PORT and
compose project. Same-repo parallel variants need distinct directory names
(git worktrees with different folder names get separate workdirs).

## Gotchas — each cost a debugging round
- **crabbox refuses repo-configured SSH hosts.** Box identity lives in the user
  config; `cbx.sh` also exports `CRABBOX_STATIC_HOST` as explicit approval.
- **Never bind public ports on the box** if it serves anything else. Everything
  stays on the box's localhost; reach it via `cbx.sh tunnel`.
- **`down` ≠ wipe.** Files persist for fast re-sync. Reclaim ONE repo:
  `ssh <alias> 'rm -rf ~/work/static_<host-with-dashes>/<repo>'`. Never delete
  `~/work` wholesale — other projects live there.
- **Rootless docker limits:** no ports <1024 (fine for dev ports), no root
  Docker daemon access (deliberate). testcontainers etc. work via `DOCKER_HOST`
  (host-prep exports it in the runner's `.bashrc`).
- **sshd `AllowUsers`:** if the box restricts SSH users, the runner user must be
  added (host-prep handles it) — otherwise key auth fails with no useful error.
- **fail2ban:** if the box runs it, a few failed auths can full-IP-ban you.
  Pin `ssh.key` in the user config so no wrong keys are ever offered; consider
  raising the sshd jail's maxretry.
- **Ubuntu 24.04+ userns restriction** (`apparmor_restrict_unprivileged_userns=1`)
  is handled by docker-ce-rootless-extras' shipped profile — install via apt,
  don't hand-roll.
- **Transient network blips** between laptop and box can look exactly like a
  ban (all ports timing out). Check from a second vantage (e.g. check-host.net)
  before touching firewall config.
- Occasional `warning: egress remote client cleanup failed … exit status 255`
  after a run is cosmetic; the run's own exit code is what counts.
