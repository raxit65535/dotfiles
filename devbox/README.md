# Devbox

Devbox is the bootstrap system for this dotfiles repository.

It can:

- install developer tooling for macOS or Ubuntu
- create and maintain symlinks from the repo into your home directory
- run in symlink-only mode when you do not want package installation

## Files

- `bootstrap.py`: entry point
- `config.json`: machine profile, install toggles, and symlink map
- `tasks/`: task implementations for base setup, languages, containers, editors,
  browsers, kubernetes, and dotfiles links

## Requirements

- Python 3
- For install tasks:
  - macOS: Homebrew
  - Ubuntu: sudo + apt

## Usage

Run from repository root.

### 1) Full bootstrap (installs + symlinks)

```bash
python devbox/bootstrap.py --config devbox/config.json --mode all
```

### 2) Install tasks only

```bash
python devbox/bootstrap.py --config devbox/config.json --mode install
```

### 3) Symlinks only

```bash
python devbox/bootstrap.py --config devbox/config.json --mode symlinks
```

### 4) Revert symlinks (restore backups)

```bash
python devbox/bootstrap.py --config devbox/config.json --mode revert
```

For each managed symlink:

- if a backup exists (`*.backup.1`), the symlink is removed and the backup is
  moved back to the original path
- if no backup exists, the symlink is removed and nothing is restored

Preview what revert would do without making any changes:

```bash
python devbox/bootstrap.py --config devbox/config.json --mode revert --dry-run
```

### 5) Symlink dry run (no file writes)

Use this to preview exactly what would happen before touching your real home
directory.

```bash
python devbox/bootstrap.py --config devbox/config.json --mode symlinks --dry-run
```

## Safe Validation Strategy

If you want an extra safety layer, run symlink mode against a temporary HOME:

```bash
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" python devbox/bootstrap.py --config devbox/config.json --mode symlinks --dry-run
HOME="$TEST_HOME" python devbox/bootstrap.py --config devbox/config.json --mode symlinks
HOME="$TEST_HOME" zsh -ic "echo shell-start-ok"
```

Why this is safe:

- your real `~` is untouched
- dry run previews planned actions first
- a real apply in temp HOME verifies symlink creation behavior
- shell startup check catches obvious sourcing issues

## Applying Symlinks

Once the dry run looks correct, apply to your real home:

```bash
python devbox/bootstrap.py --config devbox/config.json --mode symlinks
```

After applying, any pre-existing files that were replaced get moved to
`*.backup.1` (or `.backup.2`, etc.) in the same directory. Once you have
verified the new symlinks work correctly, clean them up:

```bash
find ~ -maxdepth 3 -name "*.backup.*" -exec ls -lh {} +   # preview first
find ~ -maxdepth 3 -name "*.backup.*" -exec rm {} +        # then delete
```

## Reverting Symlinks

If something breaks after applying, use the built-in revert mode:

```bash
# Preview first
python devbox/bootstrap.py --config devbox/config.json --mode revert --dry-run

# Apply
python devbox/bootstrap.py --config devbox/config.json --mode revert
```

After reverting, your files are plain files again — no symlinks pointing into
the repo. Revert respects the same profile and platform filters as apply, so
only entries that would have been linked get reverted.

## Symlink Behavior

When not in dry-run mode:

- if target already points to correct source, nothing changes (idempotent)
- if target is a regular file/directory, it is moved to `*.backup.N`
- then the new symlink is created

Re-running symlink mode is always safe — it skips anything already correct.

## Config Notes

`config.json` controls:

- `machine_profile` (for example `global` or `work`)
- `install` flags per tool area
- `symlinks` entries with optional `profiles` and `platforms`

Platform filtering values used by symlink entries:

- `macos`
- `ubuntu`

## Troubleshooting

- Unsupported platform error:
  - only macOS and Linux are supported by context detection
- Missing symlink source:
  - verify source path exists in repo and entry is correct in `config.json`
- Unexpected profile skips:
  - verify `machine_profile` and `profiles` fields
- Unexpected platform skips:
  - verify `platforms` fields and current OS
