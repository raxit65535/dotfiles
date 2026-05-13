# VS Agents Workspace

Central workspace for VS Code Copilot Chat customization.

This folder is intended to be symlinked to `~/.vs-agents` and used as your
single source for:

- custom agents
- custom skills
- MCP scaffolding
- hooks scaffolding
- OpenSpec templates and usage notes

## Folder Layout

- `agents/` custom agent personas and team instructions
- `skills/` reusable skills (one folder per skill)
- `specs/` OpenSpec starter templates
- `mcp/` MCP config templates and onboarding notes
- `hooks/` hook templates and onboarding notes

## Why Skills Use Subfolders

Skills are packaged by capability, not by file name.

Each skill lives in its own folder and uses `SKILL.md`, for example:

- `skills/openspec-workflow/SKILL.md`
- `skills/validate-changes/SKILL.md`

This keeps each skill self-contained and allows future additions like examples,
scripts, or metadata inside that same skill folder.

## How to Use Awesome Copilot Content

Use `skills/awesome-copilot-adoption` as your import process:

1. Pick one capability from awesome-copilot (do not bulk import).
2. Adapt naming/frontmatter to local conventions.
3. Add one smoke scenario to validate behavior.
4. Keep, tune, or discard based on real usage.

Start with planning/review skills first, then implementation-heavy ones.

## How to Use OpenSpec

Your understanding is correct: OpenSpec artifacts belong in the repo where the
feature is being planned and built.

Use these customizations as workflow guidance only:

1. In target repo, initialize or use existing `openspec/`.
2. Use `spec-writer` + `openspec-workflow` to produce proposal and tasks.
3. Execute tasks with normal coding agents.
4. Validate and review with `validate-changes` and `gatekeeper` style flow.

Use templates from `specs/` as starter content to avoid writing specs from
scratch.

## VS Code Copilot Settings (Manual)

Global settings were intentionally not auto-modified.

In VS Code Settings UI, set:

- custom agents path: `~/.vs-agents/agents`
- custom skills path: `~/.vs-agents/skills`

If your build exposes one root path instead, set:

- custom agents root: `~/.vs-agents`

Then:

1. Reload window.
2. Open Copilot Chat.
3. Confirm custom agents and skills are discoverable.

## Symlink Behavior FAQ

Q: If I edit `~/.vs-agents`, will dotfiles repo update too?

A: Yes. A symlink points both paths to the same underlying files. Changes from
either path affect the same content.

Q: How do I verify the link target?

A: Run:

```bash
ls -la ~/.vs-agents
readlink ~/.vs-agents
```

## Current Scope

Implemented now:

- richer agent set aligned with your `~/.agents` patterns
- richer skills inspired by Glayvin workflow style
- practical MCP/hooks scaffolding templates

Deferred for later:

- active MCP server credentials and trusted execution policy
- production hook enforcement strategy
