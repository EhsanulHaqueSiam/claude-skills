---
name: context7
description: >
  Retrieve up-to-date library documentation and code examples from Context7.
  Use when working with any programming library or framework and you need
  current API docs, usage examples, or version-specific documentation.
  Triggers: user asks about a library API, needs code examples for a specific
  library, references a package/framework by name, or you need to verify
  current library behavior before writing code.
allowed-tools: Bash(bun ~/.claude/skills/context7/context7.ts:*)
---

# Context7

Fetch version-specific documentation and code examples for any programming library directly from source repositories.

## Workflow

### 1. Resolve library ID

```bash
bun ~/.claude/skills/context7/context7.ts resolve-library-id \
  --query "<what the user needs>" \
  --library-name "<library name>"
```

Returns a Context7-compatible library ID (e.g., `/vercel/next.js`, `/mongodb/docs`).

Skip this step if the user provides an ID in `/org/project` format.

### 2. Query documentation

```bash
bun ~/.claude/skills/context7/context7.ts query-docs \
  --library-id "<id from step 1>" \
  --query "<specific question>"
```

## Example

```bash
# Find the library ID for React
bun ~/.claude/skills/context7/context7.ts resolve-library-id \
  --query "useEffect cleanup function" --library-name "react"

# Query docs with the returned ID
bun ~/.claude/skills/context7/context7.ts query-docs \
  --library-id "/facebook/react" \
  --query "How to use useEffect cleanup function"
```

## Constraints

- Call each command at most 3 times per question.
- Never include sensitive data (API keys, passwords) in queries.
- Be specific in `--query` — prefer "How to set up JWT auth in Express" over "auth".
