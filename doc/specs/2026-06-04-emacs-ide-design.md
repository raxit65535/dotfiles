# Emacs IDE Configuration Design

**Date:** 2026-06-04
**Status:** Proposed and user-approved for implementation

## Goal

Create a new `emacs/` folder in this dotfiles repository that provides a professional macOS GUI Emacs setup as a Neovim replacement IDE.

The setup should:

- use `evil-mode` as the primary editing model
- preserve the user's daily Neovim keybindings as closely as practical
- port key editor behavior from `nvim/init.lua`
- support the user's current development languages and workflows
- fit the repository's existing dotfiles + symlink workflow
- include clear setup and usage documentation
- explicitly defer AI/Copilot integration to a later phase

## Context

The repository already contains editor-specific configuration folders:

- `nvim/`
- `sublime/`
- `vscode/`

The existing Neovim configuration in `nvim/init.lua` is the primary source of truth for the desired editing experience. It currently includes:

- Vim leader key setup
- line numbers + relative numbers
- indentation defaults with language overrides
- Telescope for file/buffer/grep navigation
- `nvim-tree` for file tree
- LSP support
- format on save
- treesitter
- toggle terminal
- comment support
- statusline
- which-key
- diagnostics navigation
- keybindings for save/quit/navigation/LSP/terminal

The Emacs setup should reproduce this experience as a first-class IDE configuration for GUI Emacs on macOS using `~/.config/emacs/` as the canonical target.

## Non-goals

This phase does **not** include:

- GitHub Copilot integration
- chat/AI tooling
- org-mode workflow customization
- email/calendar/personal knowledge system features
- remote development workflows
- trying to turn Emacs into a full framework distribution like Doom or Spacemacs

## User requirements

The user explicitly requested:

1. Emacs should replace Neovim as the main editor/IDE.
2. Keybindings should stay aligned with the user's Neovim defaults and overrides.
3. Existing Neovim behavior in `nvim/init.lua` should be ported where practical.
4. The setup should run in GUI Emacs on macOS.
5. Configuration should live in this repo under a new `emacs/` directory.
6. Symlink setup should match the existing dotfiles workflow.
7. Documentation should cover setup, usage, and keyboard shortcuts.
8. AI/Copilot should be deferred until later.
9. Additional sensible IDE features beyond strict Neovim parity are welcome.

## Proposed approach

Use a standalone modular Emacs configuration under `emacs/` built with:

- `straight.el` for package management
- `use-package` for package declaration and organization
- `evil` + `evil-collection` for Vim-first editing
- modular `.el` files under `emacs/lisp/`
- repo-managed symlink into `~/.config/emacs`

This approach is preferred over Doom/Spacemacs or a large single-file config because it is:

- reproducible
- easier to maintain as dotfiles
- closer to the user's own config ownership model
- easier to extend later with AI/Copilot
- easier to reason about and document

## Architecture

### Repository layout

The following files and directories will be added:

```text
dotfiles/
  emacs/
    early-init.el
    init.el
    README.md
    lisp/
      init-core.el
      init-ui.el
      init-evil.el
      init-completion.el
      init-project.el
      init-lsp.el
      init-format.el
      init-git.el
      init-terminal.el
      init-languages.el
      init-keybindings.el
```

### Responsibilities

- `early-init.el`
  - startup performance tuning
  - suppress default package initialization when using `straight.el`
  - minimal GUI startup defaults

- `init.el`
  - bootstrap `straight.el`
  - bootstrap `use-package`
  - load modular files from `lisp/`

- `init-core.el`
  - general editor defaults
  - file handling
  - backup/lockfile preferences
  - search behavior
  - clipboard, scrolling, tabs/spaces, line numbers

- `init-ui.el`
  - theme
  - modeline
  - font/UI defaults for GUI macOS Emacs
  - relative line numbers, fringe, cursor line, helpful visual defaults

- `init-evil.el`
  - `evil`
  - `evil-collection`
  - leader key framework via `general`
  - undo behavior and modal editing defaults

- `init-completion.el`
  - minibuffer completion stack
  - `vertico`, `orderless`, `marginalia`, `consult`, `embark`
  - in-buffer completion via `corfu` and `cape`

- `init-project.el`
  - project navigation
  - file tree
  - workspace-aware search and file switching

- `init-lsp.el`
  - LSP client setup
  - diagnostics UI
  - xref/navigation integration

- `init-format.el`
  - format-on-save behavior
  - per-language formatter routing

- `init-git.el`
  - Magit
  - gutter/hunk navigation
  - optional blame and diff helpers

- `init-terminal.el`
  - embedded terminal workflow
  - keybindings for toggle/focus behavior

- `init-languages.el`
  - language-specific hooks for Go, Python, SQL, shell, Markdown, JSON, Lua

- `init-keybindings.el`
  - final global bindings and leader mappings
  - explicit parity mappings from Neovim config

## Feature mapping from Neovim

### Editor defaults to port

The following behavior should be ported from `nvim/init.lua`:

- line numbers enabled
- relative line numbers enabled in normal state
- default tab width: 2
- default shift width / indentation: 2
- spaces instead of tabs
- disable wrap by default
- enable cursor line highlight
- keep visible sign/fringe space
- scroll margin similar to Neovim `scrolloff`
- disable swap/lockfile clutter where practical
- enable persistent history/recents equivalents where helpful
- search is case-insensitive by default and smart-case aware
- split behavior should feel predictable and IDE-friendly
- system clipboard integration
- dark theme
- GUI mouse support

### Package/plugin equivalents

#### Theme

Neovim source:
- `catppuccin/nvim`

Emacs target:
- `catppuccin-theme`

#### File tree

Neovim source:
- `nvim-tree`

Emacs target:
- `treemacs`
- optional `treemacs-projectile` or project integration if needed

#### Fuzzy finding and search

Neovim source:
- Telescope

Emacs target:
- `vertico`
- `consult`
- `orderless`
- `marginalia`
- `embark`

These together provide:
- find files
- live grep / ripgrep search
- buffer switching
- symbol and project navigation

#### LSP

Neovim source:
- `nvim-lspconfig`
- `mason`
- `mason-tool-installer`

Emacs target:
- `eglot`

Rationale:
- built into modern Emacs
- lower config complexity than `lsp-mode`
- strong enough for the requested IDE-first setup
- easier to maintain in dotfiles

External language servers will be installed outside Emacs and documented in README rather than managed inside Emacs.

#### Formatting

Neovim source:
- `conform.nvim`

Emacs target:
- `apheleia`

Rationale:
- reliable formatter dispatch
- clean format-on-save model
- good per-language configuration

#### Completion

Neovim source:
- `blink.cmp`

Emacs target:
- `corfu`
- `cape`
- `kind-icon` or similar optional UI enhancer if it remains low-friction

#### Syntax highlighting / treesitter

Neovim source:
- `nvim-treesitter`

Emacs target:
- built-in tree-sitter support (`treesit`) where available
- fall back gracefully to major modes where tree-sitter grammars are unavailable

#### Terminal

Neovim source:
- `toggleterm.nvim`

Emacs target:
- `vterm`

#### Commenting

Neovim source:
- `Comment.nvim`

Emacs target:
- `evil-nerd-commenter`
  or minimal wrapper around built-in commenting if that yields cleaner key parity

#### Status line

Neovim source:
- `lualine`

Emacs target:
- `doom-modeline`

#### Key discovery

Neovim source:
- `which-key.nvim`

Emacs target:
- `which-key`

#### Git UX extras

Neovim source:
- implicit hunk/blame intentions in custom mappings

Emacs target:
- `magit`
- `diff-hl`

This is intentionally stronger than current Neovim parity and gives Emacs a meaningful IDE advantage.

## Keybinding design

### Core principle

If a key is part of the user's daily Neovim muscle memory, keep it the same unless GUI Emacs on macOS makes that unsafe, unstable, or impractical.

Where exact parity is not realistic, choose the closest stable Emacs equivalent and document the difference explicitly.

### Modal editing

Use:

- `evil-mode`
- `evil-collection`
- leader key on `SPC`

### Planned key parity

#### File operations

- `SPC w` → save current buffer
- `SPC q` → quit current buffer/window

#### Tree / navigation / search

- `SPC e` → toggle Treemacs
- `C-b` → toggle Treemacs
- `C-p` → find files
- `SPC f f` → find files
- `SPC f g` → live grep
- `SPC f b` → switch buffers
- `SPC f w` → search current word/symbol

#### LSP

- `g d` → definition
- `g r` → references
- `g i` → implementation
- `K` → hover documentation
- `<f2>` → rename symbol
- `SPC .` → code action
- `SPC f` → format buffer

#### Window and buffer navigation

- `C-h` → focus left window
- `C-j` → focus lower window
- `C-k` → focus upper window
- `C-l` → focus right window
- `TAB` → next buffer
- `S-TAB` → previous buffer

#### Jump navigation

- `C-o` → jump back
- forward-jump equivalent will be bound as closely as practical after evaluating stable Emacs/macOS key behavior

#### Diagnostics

- `[ d` → previous diagnostic
- `] d` → next diagnostic
- `SPC d` → show diagnostic at point / diagnostics UI

#### Terminal

- `SPC t` → terminal toggle
- terminal escape behavior will be documented with an Emacs-friendly equivalent

#### Comments / key hints

- `g c` and visual commenting flow preserved where practical
- `SPC ?` → which-key popup

### Compatibility notes

Some exact control-character combinations from Neovim may not behave identically in macOS GUI Emacs. These should be tested practically, and the README must document any substitutions.

## Language support

Initial language support should cover the user's current stack from Neovim:

- Go
- Python
- SQL
- shell / bash
- Markdown
- JSON
- Lua (for configuration editing convenience)

### Language-specific behavior

#### Go

- LSP via `gopls`
- format on save
- 4-space indentation to match current Emacs port target from Neovim overrides
- optional `go-ts-mode` or `go-mode` depending on installed Emacs and grammar support

#### Python

- LSP via `pyright` or `basedpyright`
- format on save
- lint/fix support via external formatter configuration
- 4-space indentation

#### SQL

- LSP if configured and practical
- formatter integration
- readable SQL editing defaults

#### Shell

- `bash-language-server` or equivalent with Eglot
- `shfmt` on save

#### Markdown

- wrap support enabled locally for Markdown buffers only
- preview is optional and not required for phase 1
- formatting support can be documented if external tooling is installed

## External tool strategy

Unlike Neovim `mason`, Emacs will not manage external tools internally in phase 1.

The README should document required external tooling, including examples such as:

- `gopls`
- `gofumpt`
- `pyright` or `basedpyright`
- `ruff` and/or `black`/`isort`
- `sqlfluff` or `sql-formatter`
- `bash-language-server`
- `shfmt`
- `ripgrep`
- `fd`
- `cmake`/`libvterm` prerequisites for `vterm` if required

This keeps the Emacs config transparent and avoids hidden package-manager behavior.

## Symlink and bootstrap integration

### Makefile changes

Add:

- `symlink-emacs`

Update the aggregate `symlink` target to include Emacs if desired.

Example responsibility:
- remove existing `~/.config/emacs`
- ensure `~/.config` exists
- create symlink from repo `emacs/` to `~/.config/emacs`

### Devbox config changes

Add a symlink entry in `devbox/config.json`:

- source: `emacs`
- target: `~/.config/emacs`
- platform: `macos`
- profiles: `global`, `work`

### Optional editor installer integration

A later enhancement may update `devbox/tasks/editors.py` to install GUI Emacs with Homebrew cask. This is optional for phase 1 and not required to land the config itself.

## Documentation plan

Create `emacs/README.md` with these sections:

1. overview and goals
2. folder structure
3. prerequisites
4. first-time setup
5. symlink setup
6. package bootstrap behavior
7. required external tools by language
8. feature summary
9. keybinding cheat sheet
10. known differences from Neovim
11. troubleshooting
12. future extensions (AI/Copilot later)

The README must be good enough for the user to adopt Emacs without needing to inspect the Lisp files first.

## Testing and validation plan

This is a dotfiles/configuration repository, so validation should be practical and evidence-based.

### Minimum validation

- verify all new files exist in the expected locations
- ensure `Makefile` targets are syntactically correct
- ensure `devbox/config.json` remains valid JSON
- run a dry-run or safe symlink verification if possible
- byte-compile or batch-load Emacs Lisp files if Emacs is available locally
- review README commands for consistency with actual config behavior

### Success criteria

The implementation is successful when:

1. `emacs/` exists with a modular configuration.
2. `~/.config/emacs` can be symlinked from this repo.
3. GUI Emacs starts and bootstraps packages successfully.
4. Evil mode is active by default.
5. Daily Neovim-style navigation, search, tree, LSP, formatting, terminal, and diagnostics workflows are available.
6. The keybinding guide clearly documents how to use the setup.
7. The setup supports Go, Python, SQL, shell, and Markdown workflows.

## Risks and mitigations

### Risk: exact keybinding parity is not always possible

Mitigation:
- preserve the most important keys exactly
- document unavoidable differences clearly
- choose stable macOS GUI Emacs bindings over clever fragile hacks

### Risk: external tool mismatch across languages

Mitigation:
- make required tools explicit in README
- prefer simple formatter/LSP wiring
- avoid trying to embed a Mason-like layer in Emacs in phase 1

### Risk: Emacs package complexity grows too fast

Mitigation:
- keep config modular
- only include packages that directly support the IDE goal
- defer AI and unrelated Emacs ecosystems to later phases

### Risk: tree-sitter availability varies by Emacs installation

Mitigation:
- use built-in support when present
- degrade gracefully to standard major modes

## Implementation recommendation

Implement in this order:

1. create Emacs folder structure and bootstrap files
2. establish core defaults and UI
3. configure Evil and leader keys
4. configure completion/navigation stack
5. configure Treemacs, project tools, and search
6. configure Eglot and diagnostics
7. configure Apheleia and formatter hooks
8. configure terminal and git enhancements
9. configure language-specific hooks
10. add symlink integration in Makefile and `devbox/config.json`
11. write README and shortcut documentation
12. validate loadability and configuration integrity

## Final recommendation

Proceed with a standalone modular Emacs IDE configuration under `emacs/`, using `evil` as the primary editing model, preserving Neovim keybindings and behavior where practical, integrating with the existing dotfiles symlink workflow, and documenting setup thoroughly for GUI Emacs on macOS.
