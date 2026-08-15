#!/usr/bin/env bash
#
# cbx.sh — front-door wrapper around crabbox on the static Hetzner box.
#
# SAME INTERFACE as the Daytona version (up/logs/tunnel/pw/get/down) so the other
# loop-engineer skills compose unchanged. Static SSH differences: no 60s exec cap
# (setup runs synchronously, no bg+poll), tunnel/get use plain ssh/scp via the
# `crabbox` ~/.ssh/config alias, and `down` stops THIS project's processes — the
# box itself persists and is shared.
#
#   bash cbx.sh up   <name>            # sync + run setup.sh → STACK READY
#   bash cbx.sh logs <name>            # tail the setup/dev logs
#   bash cbx.sh tunnel <name> &        # SSH tunnel: localhost → box (use a local browser)
#   bash cbx.sh pw   <name> -- <args>  # run playwright-cli IN the box (in the repo workdir)
#   bash cbx.sh get  <name> <remote> <local>   # pull a file off the box
#   bash cbx.sh down <name>            # stop THIS repo's dev server + containers
set -euo pipefail

# ── EDIT: project config ────────────────────────────────────────────────────
APP_PORT=3000                        # must match setup.sh; UNIQUE per project (shared box)
TUNNEL_PORTS="3000:localhost:3000"   # space-separated -L specs
READY_MARKER="STACK READY"
# secrets in env.allow are forwarded from your SHELL. We source .env so they're set.
[ -f .env ] && { set -a; . ./.env; set +a; }
[ -f .env.local ] && { set -a; . ./.env.local; set +a; }
# ── static box (EDIT once; must match ~/.config/crabbox/config.yaml) ────────
BOX_HOST="${CRABBOX_BOX_HOST:-}"     # EDIT: your VPS IP/hostname, e.g. 203.0.113.7
SSH_ALIAS="${CRABBOX_SSH_ALIAS:-crabbox}"  # ~/.ssh/config alias → <runner-user>@$BOX_HOST
[ -n "$BOX_HOST" ] || { echo "✗ set BOX_HOST in cbx.sh (or CRABBOX_BOX_HOST env)" >&2; exit 1; }
export CRABBOX_STATIC_HOST="$BOX_HOST"     # explicit approval of the credential destination
BOX_ID="${BOX_HOST//./-}"
REPO="$(basename "$(pwd)")"
BOX_DIR="work/static_${BOX_ID}/${REPO}"    # repo workdir, relative to the box $HOME
# ────────────────────────────────────────────────────────────────────────────

CMD="${1:-}"; NAME="${2:-demo}"

case "$CMD" in
up)
  echo "▸ sync + setup on the box (synchronous — static SSH has no exec cap)…"
  crabbox run -- bash -c "bash setup.sh 2>&1 | tee /tmp/setup-${REPO}.log" \
    && echo "✓ ${READY_MARKER} — app on the box at localhost:${APP_PORT}" \
    || { echo "✗ setup failed (tail of log):"; ssh "$SSH_ALIAS" "tail -15 /tmp/setup-${REPO}.log"; exit 1; }
  ;;

logs)   ssh "$SSH_ALIAS" "tail -40 /tmp/setup-${REPO}.log /tmp/dev-${REPO}.log 2>/dev/null" ;;

tunnel)
  L=""; for p in $TUNNEL_PORTS; do L="$L -L $p"; done
  echo "▸ tunneling$L  (Ctrl-C to stop) → open http://localhost:${APP_PORT}"
  # shellcheck disable=SC2086
  ssh -N $L "$SSH_ALIAS"
  ;;

pw)     shift 2 || true; [ "${1:-}" = "--" ] && shift || true
        crabbox run --no-sync -- playwright-cli "$@" ;;

get)    REMOTE="${3:?usage: get <name> <remote> <local>}"; LOCAL="${4:?usage: get <name> <remote> <local>}"
        scp -q "$SSH_ALIAS:$REMOTE" "$LOCAL"
        echo "✓ pulled $REMOTE → $LOCAL ($(wc -c < "$LOCAL") bytes)" ;;

down)
  # Stop only THIS project's things: dev-server process group (pid file written
  # by setup.sh) + compose project named after the repo. Never touches other
  # repos' processes, the box, or anything outside the crabbox user.
  ssh "$SSH_ALIAS" "
    [ -f /tmp/dev-${REPO}.pid ] && { kill -- -\$(cat /tmp/dev-${REPO}.pid) 2>/dev/null || true; rm -f /tmp/dev-${REPO}.pid; }
    cd ~/${BOX_DIR} 2>/dev/null && docker compose -p '${REPO}' down 2>/dev/null || true
    echo '✓ ${REPO} stopped (files kept for fast re-sync; wipe: rm -rf ~/${BOX_DIR})'"
  crabbox stop --id "$BOX_ID" 2>/dev/null | tail -1 || true
  ;;

*)      echo "usage: bash cbx.sh {up|logs|tunnel|pw|get|down} <name>"; exit 1 ;;
esac
