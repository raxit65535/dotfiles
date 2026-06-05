# Hybrid AI Worktree Review Workflow Design

**Date:** 2026-06-05
**Status:** Approved

## Goal

Define a practical feature-development workflow that combines:

- git worktrees for feature isolation
- IDE-first manual development and review
- tmux sessions for long-running AI implementation tasks
- lightweight CLI / Neovim review for docs and first-pass code inspection

The workflow should improve human oversight of AI-generated changes without creating excessive tooling or maintenance overhead.

## Context

Current workflow:

- open a repo in VS Code
- open an integrated terminal
- create a feature branch in the main checkout
- develop using AI CLI tools and/or IDE chat
- manually review changes heavily
- commit manually
- push branch and open a PR manually

Desired direction:

- keep IDEs as the primary environment for coding, navigation, testing, GitHub/PR work, and Copilot Chat
- use tmux only when it adds clear value, especially for long-running AI implementation sessions
- experiment with Neovim/CLI review before relying on IDE review exclusively
- improve review quality for multi-commit AI output
- avoid a workflow that requires lots of repetitive `cd` navigation or session maintenance

## Principles

1. **IDE-first by default.** VS Code / JetBrains remain the primary workspace for normal development and deep review.
2. **Worktree per feature.** Each feature gets its own branch and its own filesystem checkout.
3. **tmux is optional, not mandatory.** Launch `cop` only when delegating meaningful long-running AI work.
4. **Human review before push.** AI commits are checkpoints, not trusted final history.
5. **CLI review is additive.** Neovim and terminal tooling should improve speed and awareness, not replace the IDE prematurely.
6. **Keep tooling lightweight.** Prefer a few strong commands and small wrappers over an elaborate platform.

## Proposed Operating Model

### Source-control model

A git worktree does not replace a branch. Instead:

- **branch** = history lane
- **worktree** = directory checked out to that branch

Recommended feature start flow:

1. update `main`
2. create a feature branch in a new worktree
3. open the worktree path directly in the IDE
4. do implementation there
5. optionally launch `cop` for the same worktree when delegating a substantial AI task
6. review heavily before push
7. clean up commit history if needed
8. push the branch
9. open the PR
10. remove the worktree and tmux session after merge or abandonment

Example:

```bash
git fetch origin
git switch main
git pull --ff-only
git worktree add .worktrees/feat-x -b feat-x main
code .worktrees/feat-x
```

Then inside `.worktrees/feat-x`:

```bash
git add -A
git commit -m "..."
git push -u origin feat-x
```

### Division of responsibilities

**IDE**
- manual coding and refactoring
- code navigation and references
- test runs and validation
- GitHub / PR interaction
- final human review and polish
- Copilot Chat iteration

**tmux / `cop` session**
- long-running AI implementation tasks
- persistent shell / review / watch windows
- detached execution that can be resumed later
- terminal-based review before or alongside IDE review

**Neovim / CLI**
- review `doc/*` and markdown specs/plans/tasks
- branch-wide and commit-wise first-pass review
- quick changed-file inspection
- surgical follow-up edits
- fallback review surface when IDE is unnecessary

## When to Use `cop`

### Use `cop` when

- the AI task is large enough to run for a while
- you want a persistent execution context you can detach from
- you want dedicated review, shell, and watch windows
- you are isolating one feature’s delegated implementation work
- long-lived logs, tests, or watchers would clutter the IDE

### Do not use `cop` when

- the task is small or mostly manual
- you are iterating quickly in the IDE with Copilot Chat
- no persistent watcher/log windows are needed
- tmux adds ceremony without clear benefit

## Tmux Session Model

Recommended model:

- one tmux session per feature worktree
- session name: `<repo>-<feature-short-name>`
- session is an execution workspace, not the universal home base

Recommended windows:

1. **agent** — AI CLI implementation work
2. **review** — git diff/log review, optional Neovim review
3. **shell** — ad hoc git/test/build/rebase/fixup commands
4. **watch** — test watch, typecheck watch, logs, dev server

Recommended session habits:

- keep one top-level tmux client open in iTerm2
- use `C-a s` to switch sessions
- use `C-a L` to jump back to the last session
- use `M-1` through `M-4` for window switching within a session
- prefer separate sessions for separate features instead of overloading one session with unrelated windows

## Human Review Workflow for AI-Generated Changes

Use three review passes before push.

### Pass 1: branch-wide review

Goal: understand the feature as one change.

Primary commands:

```bash
git log --oneline main..HEAD
git diff --stat main...HEAD
git diff main...HEAD | delta
```

Primary surfaces:
- tmux `review` window
- IDE worktree window for changed-file browsing and navigation

### Pass 2: commit-by-commit review

Goal: inspect AI intermediate commits and spot churn, reversals, or unnecessary checkpoints.

Primary commands:

```bash
git log --oneline main..HEAD
git show <hash> | delta
git diff <hash>^!
```

This pass determines whether history should be cleaned up before push.

### Pass 3: manual correction and history shaping

Goal: make the feature production-ready.

Primary actions:
- manual edits in IDE or Neovim
- interactive staging with `git add -p`
- cleanup commits with `git commit --fixup` and `git rebase -i main`
- final validation before push

AI commits should be treated as reviewable working checkpoints, not final commit history.

## IDE Review Guidance

The IDE remains the primary deep-review surface.

### VS Code / JetBrains usage

Open the worktree directory itself, not the main checkout.

Use the IDE for:
- changed-file review
- navigation-heavy investigation
- references / implementations / symbol search
- running tests and fixes
- PR preparation and GitHub integration

Recommended role in the review stack:
- tmux/CLI for fast branch overview
- IDE for deeper file-level and semantic review
- PR UI as the final external review surface, not the first serious inspection point

## Neovim / CLI Review Guidance

Neovim is explicitly allowed as a review tool in this workflow, especially inside the tmux `review` window.

Best-fit use cases:
- reviewing `doc/specs`, `doc/plans`, and markdown notes
- first-pass code review of changed files
- hunk and commit review
- quick edits after branch-wide inspection

Neovim is not required to replace the IDE. It should provide leverage where terminal speed matters.

### Minimum useful terminal review flow

```bash
git log --oneline main..HEAD
git diff --stat main...HEAD
git diff main...HEAD | delta
```

Then open Neovim for:
- suspicious files
- markdown updates
- targeted fixes

If review turns navigation-heavy, move to the IDE.

### Candidate Neovim review tools to evaluate

- `delta` for terminal diff rendering
- `diffview.nvim` for multi-file diff review
- `gitsigns.nvim` for hunk navigation and staging
- `vim-fugitive` for mature Git workflows

The design favors the minimum plugin set that materially improves review quality.

## Worktree Entry Workflow

The worktree workflow must not depend on frequent manual `cd` hopping across many repos.

### Desired user experience

Think in terms of opening a **feature workspace**, not branching inside a single reusable repo checkout.

Recommended flow:

1. choose repo
2. create or reopen feature worktree
3. open that worktree directly in the IDE
4. optionally attach tmux for delegated AI execution

### Workflow requirement

Provide a lightweight helper command or wrapper so the user does not need to manually navigate to the repo root each time.

Target UX shape:

```bash
feature-open <repo> <feature>
```

or equivalent behavior via `cop` plus a worktree helper.

That helper should:
- resolve the repo path
- create `.worktrees/<feature>` if missing
- create the branch if needed
- reopen the existing worktree if already created
- open the worktree in VS Code or JetBrains

## `cop` / `uncop` Behavioral Requirements

### `cop`

`cop` should mean:

> open or attach the tmux execution workspace for this feature worktree

Desired behavior:
- accept a session/feature name and optional worktree path
- attach if the session already exists
- otherwise create the standard four-window layout
- show a concise summary including session name, path, branch, and windows

### `uncop`

`uncop` should mean:

> close the tmux execution workspace, and optionally remove the worktree when the feature is done

Desired behavior:
- kill the tmux session safely
- optionally remove the worktree
- avoid removing the main repo checkout
- default to conservative cleanup

## Adoption Strategy

Roll out in phases instead of replacing the entire workflow immediately.

### Phase 1
- adopt worktree-per-feature
- keep IDE as default
- use tmux only for one meaningful long-running AI task
- use terminal review commands in the tmux `review` window

### Phase 2
- experiment with Neovim for `doc/*` review and changed-file inspection
- test whether commit review and markdown review feel better in tmux/nvim than in the IDE

### Phase 3
- only after proving value, refine `cop` / `uncop`
- add minimum viable Neovim Git review enhancements
- optionally add a repo/worktree launcher to remove shell-navigation friction

## Required Assessment of Current Neovim Setup

Before changing Neovim configuration, review the current `nvim/init.lua` and verify whether it is sufficient for:

1. **markdown review**
   - readable editing and rendering of `doc/*`
   - search/navigation for longer specs and plans

2. **code navigation**
   - Go
   - Python
   - JavaScript / TypeScript
   - references, definitions, hover, rename, symbol search

3. **source control review in worktrees**
   - changed files
   - hunk navigation
   - commit and branch diff review
   - conflict and rebase ergonomics where practical

If the setup is not sufficient, recommend the smallest useful upgrades rather than a full Neovim overhaul.

## Non-goals

- replacing IDE review completely with Neovim
- forcing tmux use for every feature
- building a complex custom workflow framework before real usage proves the need
- automating PR creation or branch cleanup beyond what materially helps the workflow
- turning AI-generated commit history into a mandatory preserved artifact

## Acceptance Criteria

1. The workflow clearly distinguishes when to stay IDE-only and when to launch `cop`.
2. The workflow supports branch-wide, commit-wise, and hunk-wise human review of AI-generated changes before push.
3. The worktree model is documented clearly enough that commit, push, and PR flow remain intuitive.
4. The workflow includes a low-friction entry path for creating or reopening worktrees across many repos.
5. The tmux session model is simple: one feature worktree, one optional execution session, four clearly scoped windows.
6. The design explicitly supports Neovim as a viable first-pass review tool for `doc/*` and worktree code changes.
7. The implementation plan includes an assessment of the current `nvim/init.lua` for markdown review, code navigation, and worktree Git review.
8. The workflow reduces context confusion without requiring disproportionate maintenance effort.
