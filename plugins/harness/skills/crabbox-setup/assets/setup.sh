#!/usr/bin/env bash
# Brings the whole stack up: docker → services → env → deps → migrate → dev server.
#
# Dual-use:
#   • on the box  — `cbx.sh up` runs this synchronously (static SSH has no exec cap).
#   • locally     — `bash setup.sh` boots the same stack on your machine.
# IDEMPOTENT (check-before-act at every step), so it's safe to re-run and to run
# locally where some things are already up.
set -euo pipefail
cd "$(dirname "$0")"
REPO="$(basename "$(pwd)")"        # names the per-project log/pid files on the shared box

# ── EDIT: your project's commands + ports ───────────────────────────────────
APP_PORT=3000                      # dev server port — MUST be unique per project:
                                   # the box is shared, two repos on :3000 collide.
INSTALL_CMD="pnpm install"
DEV_CMD="pnpm dev"
MIGRATE_CMD="pnpm run db:migrate"  # runs on EVERY setup, incl. LOCALLY → keep it
                                   # NON-destructive & idempotent; "" if none. Do NOT default
                                   # this to a `db:reset`: it would wipe your local dev DB on
                                   # every re-run.
NEEDS_DOCKER=1                     # 1 if you run containers (DB), else 0
# ────────────────────────────────────────────────────────────────────────────

_T0=$(date +%s); _TL=$_T0
phase() { local now=$(date +%s); echo "[t] +$((now-_TL))s (total $((now-_T0))s) — $*"; _TL=$now; }

# ── docker ──────────────────────────────────────────────────────────────────
# On the box: rootless dockerd runs as a systemd --user service for the crabbox
# user (DOCKER_HOST is exported in its ~/.bashrc). Locally: system docker.
if [ "$NEEDS_DOCKER" = 1 ]; then
  if docker info >/dev/null 2>&1; then
    echo "[setup] docker already up"
  else
    systemctl --user start docker 2>/dev/null || sudo systemctl start docker 2>/dev/null || true
    for i in $(seq 1 20); do docker info >/dev/null 2>&1 && break; sleep 1; done
    docker info >/dev/null 2>&1 || { echo "[setup] dockerd failed"; exit 1; }
  fi
  phase "docker up"
fi

# ── env: ensure .env exists; inject forwarded secrets (env.allow) on the box ──
# EDIT: match your env file + secret var(s). Locally .env already exists → skipped.
if [ ! -f .env.local ] && [ -f .env.local.example ]; then cp .env.local.example .env.local; fi
# example secret injection (repeat per env.allow var):
# if [ -n "${MY_API_KEY:-}" ]; then
#   grep -q '^MY_API_KEY=' .env.local \
#     && sed -i "s|^MY_API_KEY=.*|MY_API_KEY=${MY_API_KEY}|" .env.local \
#     || echo "MY_API_KEY=${MY_API_KEY}" >> .env.local
# fi

# ── services: start your DB/etc., idempotently ──────────────────────────────
# EDIT: replace with your stack. Compose example (project-scoped so `down` can
# clean THIS project's containers without touching anything else):
# docker compose -p "$REPO" up -d --wait || { echo "[setup] services failed"; exit 1; }
phase "services up"

# ── deps + migrate ──────────────────────────────────────────────────────────
echo "[setup] install…"; $INSTALL_CMD
phase "install"
if [ -n "$MIGRATE_CMD" ]; then echo "[setup] migrate…"; $MIGRATE_CMD; phase "migrate"; fi

# ── dev server (skip if already serving) ────────────────────────────────────
if curl -sf "http://127.0.0.1:${APP_PORT}" >/dev/null 2>&1; then
  echo "[setup] dev server already up"
else
  echo "[setup] starting dev server on :${APP_PORT}…"
  # setsid → own process group; survives the ssh session ending, and cbx.sh down
  # can kill the whole group via the pid file without touching other projects.
  setsid nohup $DEV_CMD >"/tmp/dev-${REPO}.log" 2>&1 < /dev/null &
  echo $! > "/tmp/dev-${REPO}.pid"
  for i in $(seq 1 60); do curl -sf "http://127.0.0.1:${APP_PORT}" >/dev/null 2>&1 && break; sleep 2; done
  curl -sf "http://127.0.0.1:${APP_PORT}" >/dev/null 2>&1 || { echo "[setup] dev server not up"; tail -20 "/tmp/dev-${REPO}.log"; exit 1; }
fi
phase "dev server up"

echo "STACK READY"
