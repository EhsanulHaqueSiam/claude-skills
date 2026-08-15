# claude-skills

Claude Code skills, packaged as a plugin marketplace.

## Install

```
/plugin marketplace add EhsanulHaqueSiam/claude-skills
/plugin install agent-harness@siam      # the loop-engineer harness (10 skills)
/plugin install siam-skills@siam        # the full personal collection (~92 skills)
```

## agent-harness — how the skills fit together

The harness makes a repo **legible → executable → verifiable** so agents can own
work in it. `setup-codebase-harness` is the master skill that orchestrates the
others — invoke it on a new/unfamiliar repo and it walks this pipeline:

```
setup-codebase-harness            "make this repo agent-ready" — runs the rest in order
  │
  ├─ 1. Legible      slim CLAUDE.md map + docs/ + custom lints (done inline)
  ├─ 2. Executable   dev-local-setup  →  one-command local stack (scripts/dev-local.sh)
  ├─ 3. Verifiable   e2e-setup        →  trustworthy e2e gate (runs against that stack)
  │                  verifier-setup   →  generates the repo's /verify skill
  │                                      (asks: verify locally, or on the box?)
  └─ 4. Parallel?    crabbox-setup    →  only when loops run CONCURRENTLY:
                                          per-agent stack on the Hetzner box
                                          (static SSH — no Daytona)
```

**Order matters within the pipeline:**

1. **`dev-local-setup` first** — everything downstream needs a reliable
   one-command stack. `crabbox-setup` reuses its service/port discovery, and the
   e2e suite runs against the stack it starts (never boots the app itself).
2. **`e2e-setup` after dev-local** — same specs run against local stack or the
   cloud box.
3. **`verifier-setup` after both** — it generates `/verify`, which wires the
   stack (RUN_MODE local|sandbox) + driver (playwright-cli) + e2e regression
   sweep into one per-task proof loop. `/verify` is then what every feature
   branch runs before a PR.
4. **`crabbox-setup` only when you need parallelism** (N loops at once, or a
   fixed-port/single-instance stack). One agent working one repo at a time is
   fine on local — skip the box.
5. **`new-loop` last, per workstream** — once a repo is harnessed, this stands
   up a recurring loop (a domain with charter + cadence) that ships its code
   changes through `/verify`, on the box when loops run in parallel.

**Standalone skills — no pipeline, use on their own whenever the trigger fits:**

- **`agent-context-audit`** — audit a repo's CLAUDE.md/docs/skills/tools for
  overconstraint, staleness, conflicts. Use any time, on any repo; especially
  after model upgrades. Good BEFORE `setup-codebase-harness` on a repo that
  already has agent docs.
- **`open-agent-teams`** — delegate a task to any CLI agent (codex, aider,
  claude) in a detached tmux session. An alternative executor, unrelated to the
  harness pipeline.
- **`visual-flow-gif`** — turn notes/articles/architecture into a PNG + animated
  GIF diagram. Pure utility.
- **`seo-growth`** — decide WHERE to point SEO effort (cold start, cluster vs
  page, what to write next). Strategy, not page writing.

## siam-skills

A flat collection — no pipeline; each skill is invoked individually by its
trigger (design/frontend taste packs, animation skills, the seo-* toolkit,
Cloudflare/Workers, workflow utilities like `html-communication`). Browse
`plugins/siam-skills/skills/*/SKILL.md` descriptions to see triggers.

## Notes for installers

- `crabbox-setup` assumes a **prepared static-SSH box** — see its
  `assets/host-prep.sh` for the one-time root setup, then point
  `~/.config/crabbox/config.yaml` and an ssh alias at YOUR server (the shipped
  copy references the author's box).
- `open-agent-teams` needs `tmux`; `visual-flow-gif` installs Pillow on first
  use.
