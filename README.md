# claude-skills

Siam's Claude Code skills, packaged as a plugin marketplace.

## Install

```
/plugin marketplace add EhsanulHaqueSiam/claude-skills
/plugin install agent-harness@siam    # loop-engineer harness (10 skills, Hetzner port)
/plugin install siam-skills@siam      # hand-picked personal skills
```

## agent-harness

All 10 skills from [AI-Builder-Club/skills](https://github.com/AI-Builder-Club/skills)
(MIT), with the crabbox ecosystem ported from Daytona snapshots to a persistent
static-SSH VPS. Pipeline order:

```
setup-codebase-harness         master skill — orchestrates the rest
  1. dev-local-setup           one-command local stack (everything depends on it)
  2. e2e-setup                 e2e gate, runs against that stack
  3. verifier-setup            generates the repo's /verify loop (local or box)
  4. crabbox-setup             only for CONCURRENT loops — per-agent stack on the box
  5. new-loop                  recurring workstreams that ship via /verify
```

Standalone (no pipeline): agent-context-audit, open-agent-teams, visual-flow-gif,
seo-growth.

To use crabbox-setup on your own server: run `skills/crabbox-setup/assets/host-prep.sh`
as root there, then point `~/.config/crabbox/config.yaml` + an ssh alias at it.
`open-agent-teams` needs tmux; `visual-flow-gif` installs Pillow on first use.

## siam-skills

Hand-picked: **html-communication** (publish HTML pages for humans to view),
**babysit-pr** (monitor a PR: bots, CI, reviews), **file-pr**, **file-upload**,
**dogfood**, **gpt-taste**. Each fires on its own trigger — see
`plugins/siam-skills/skills/*/SKILL.md`.
