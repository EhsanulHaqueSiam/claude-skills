#!/usr/bin/env bash
# host-prep.sh — ONE-TIME root prep of a fresh VPS as a crabbox static-SSH box.
# This replaces the Daytona Dockerfile: the box persists, so tools install once.
# Run as root on the box. Idempotent.
set -euo pipefail
GH_USER="${1:?usage: host-prep.sh <github-username>   (whose keys ssh-import-id authorizes)}"
export DEBIAN_FRONTEND=noninteractive

# runner user — NO sudo, NO docker group; isolation from anything else on the box
id crabbox >/dev/null 2>&1 || adduser --disabled-password --gecos "crabbox runner" crabbox
sudo -u crabbox ssh-import-id "gh:${GH_USER}"
sudo -u crabbox mkdir -p /home/crabbox/work

# if sshd restricts users, allow crabbox (adapt to the box's config layout)
if /usr/bin/grep -rq "^AllowUsers" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ 2>/dev/null; then
  /usr/bin/grep -rl "^AllowUsers" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ | while read -r f; do
    /usr/bin/grep -q "AllowUsers.*crabbox" "$f" || sed -i "s/^AllowUsers.*/& crabbox/" "$f"
  done
  sshd -t && systemctl reload ssh
fi

# base tools + rootless docker prereqs + chrome (for playwright e2e in the box)
apt-get update -qq
apt-get install -y -qq git rsync tar curl docker-ce-rootless-extras uidmap dbus-user-session slirp4netns >/dev/null
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -qq && apt-get install -y -qq google-chrome-stable >/dev/null
loginctl enable-linger crabbox   # user services (rootless dockerd) survive logout

# toolchain + rootless docker, as the crabbox user
sudo -iu crabbox bash <<'EOSU'
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
command -v ~/.local/bin/mise >/dev/null || curl -fsSL https://mise.run | sh
~/.local/bin/mise use -g node@24 pnpm@latest
# PATH + DOCKER_HOST must sit at the TOP of .bashrc, before the interactive
# guard, so non-interactive ssh execs (what crabbox uses) see them.
/usr/bin/grep -q mise/shims ~/.bashrc || sed -i '1i export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"' ~/.bashrc
/usr/bin/grep -q DOCKER_HOST ~/.bashrc || sed -i "1i export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock" ~/.bashrc
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"
dockerd-rootless-setuptool.sh install
systemctl --user enable docker
npm i -g @playwright/cli && mise reshim
EOSU

echo "HOST-PREP-DONE — verify: ssh crabbox@<box> 'docker run --rm hello-world && node --version && playwright-cli --version'"
