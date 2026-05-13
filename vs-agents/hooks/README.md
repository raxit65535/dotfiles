# Hooks Scaffolding

This folder contains starter templates for pre/post action hooks.

## Included

- `hooks.config.example.json`: sample hook registry
- `pre-tool-use.example.sh`: guardrails before risky actions
- `post-tool-use.example.sh`: logging and lightweight policy checks

## How to Use

1. Copy templates to active local files.
2. Tune checks for your workflow.
3. Keep hooks fast and deterministic.
4. Start in warning mode before blocking mode.

## Suggested Early Hooks

- Warn on destructive git commands.
- Warn when writing secrets into tracked files.
- Warn when broad wildcard edits are attempted.
