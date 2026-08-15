# claude-skills

Claude Code skills, packaged as a plugin marketplace.

## Install

```
/plugin marketplace add EhsanulHaqueSiam/claude-skills
/plugin install agent-harness@siam      # the loop-engineer harness (7 skills)
/plugin install siam-skills@siam        # the full personal collection
```

## Plugins

- **agent-harness** — `setup-codebase-harness`, `dev-local-setup`, `e2e-setup`,
  `verifier-setup`, `new-loop`, `visual-flow-gif`, and `crabbox-setup` ported to a
  static-SSH VPS (Hetzner) instead of Daytona. `crabbox-setup` assumes a prepared
  box — see its `assets/host-prep.sh` for the one-time root setup and adapt the
  host/user in `~/.config/crabbox/config.yaml` + the ssh alias to your own server.
- **siam-skills** — design/frontend taste packs, animation skills, SEO toolkit,
  Cloudflare/Workers, and workflow utilities.
