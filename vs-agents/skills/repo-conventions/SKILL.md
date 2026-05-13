---
name: repo-conventions
description:
  Applies local conventions for dotfiles, bootstrap, and safe automation changes
---

# Repo Conventions

Use this skill when changing this dotfiles repository.

## Conventions

- Prefer config-driven changes in `devbox/config.json` over hardcoded scripts.
- Keep bootstrap tasks idempotent and reversible.
- Use additive symlinks and preserve existing files via backup.
- Keep personal secret data out of committed files.

## Change Checklist

1. Confirm profile and platform handling.
2. Keep naming consistent with existing symlink entries.
3. Ensure re-running bootstrap is safe.
4. Document manual post-bootstrap steps when needed.
5. Avoid touching unrelated user-specific files.
