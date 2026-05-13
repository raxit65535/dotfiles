from __future__ import annotations

import shutil
from pathlib import Path

from tasks.base import Context, Task


class DotfilesLinkTask(Task):
    name = "dotfiles"

    def run(self, ctx: Context) -> None:
        entries = ctx.config.get("symlinks", [])
        if not isinstance(entries, list):
            raise RuntimeError("config.json: 'symlinks' must be a list")

        for entry in entries:
            self._link_entry(ctx, entry)

    def _link_entry(self, ctx: Context, entry: dict) -> None:
        dry_run = bool(ctx.config.get("dry_run", False))
        name = entry.get("name", "<unnamed>")
        source_rel = entry.get("source")
        target_raw = entry.get("target")

        if not source_rel or not target_raw:
            raise RuntimeError(f"Invalid symlink entry: {name}")

        if not self._matches_profile(ctx, entry):
            ctx.log(f"Skipping symlink '{name}' due to profile mismatch")
            return

        if not self._matches_platform(ctx, entry):
            ctx.log(f"Skipping symlink '{name}' due to platform mismatch")
            return

        source = (ctx.dotfiles_root / source_rel).resolve()
        # Important: never resolve target here; resolve() follows symlinks and can
        # collapse target into source path on repeated runs.
        target = Path(target_raw).expanduser()

        if not source.exists():
            raise FileNotFoundError(f"Symlink source does not exist: {source}")

        if dry_run:
            if not target.parent.exists():
                ctx.log(f"[dry-run] Would create parent directory: {target.parent}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)

        if target.is_symlink():
            existing = target.resolve()
            if existing == source:
                prefix = "[dry-run] " if dry_run else ""
                ctx.log(f"{prefix}Symlink already correct: {target} -> {source}")
                return
            if dry_run:
                ctx.log(f"[dry-run] Would replace symlink: {target} -> {existing}")
            else:
                target.unlink()

        elif target.exists():
            backup = self._backup_path(target)
            if dry_run:
                ctx.log(
                    f"[dry-run] Would back up existing target: {target} -> {backup}"
                )
            else:
                ctx.log(f"Backing up existing target: {target} -> {backup}")
                shutil.move(str(target), str(backup))

        if dry_run:
            ctx.log(f"[dry-run] Would link {target} -> {source}")
        else:
            ctx.log(f"Linking {target} -> {source}")
            target.symlink_to(source, target_is_directory=source.is_dir())

    def _matches_profile(self, ctx: Context, entry: dict) -> bool:
        profiles = entry.get("profiles")
        if not profiles:
            return True

        machine_profile = ctx.machine_profile
        return machine_profile in profiles

    def _matches_platform(self, ctx: Context, entry: dict) -> bool:
        platforms = entry.get("platforms")
        if not platforms:
            return True
        return ctx.platform_name in platforms

    def _backup_path(self, target: Path) -> Path:
        index = 1
        while True:
            candidate = target.with_name(f"{target.name}.backup.{index}")
            if not candidate.exists():
                return candidate
            index += 1


class DotfilesRevertTask(Task):
    name = "dotfiles-revert"

    def run(self, ctx: Context) -> None:
        dry_run = bool(ctx.config.get("dry_run", False))
        entries = ctx.config.get("symlinks", [])
        if not isinstance(entries, list):
            raise RuntimeError("config.json: 'symlinks' must be a list")

        reverted = 0
        skipped = 0

        for entry in entries:
            name = entry.get("name", "<unnamed>")
            target_raw = entry.get("target")
            if not target_raw:
                continue

            profiles = entry.get("profiles")
            if profiles and ctx.machine_profile not in profiles:
                ctx.log(f"Skipping revert '{name}' due to profile mismatch")
                skipped += 1
                continue

            platforms = entry.get("platforms")
            if platforms and ctx.platform_name not in platforms:
                ctx.log(f"Skipping revert '{name}' due to platform mismatch")
                skipped += 1
                continue

            target = Path(target_raw).expanduser()
            backup = self._latest_backup(target)

            if not target.is_symlink():
                ctx.log(f"Skipping revert '{name}': target is not a symlink")
                skipped += 1
                continue

            if backup is None:
                if dry_run:
                    ctx.log(f"[dry-run] Would remove symlink (no backup found): {target}")
                else:
                    ctx.log(f"Removing symlink (no backup found): {target}")
                    target.unlink()
                reverted += 1
                continue

            if dry_run:
                ctx.log(f"[dry-run] Would restore: {backup} -> {target}")
            else:
                target.unlink()
                shutil.move(str(backup), str(target))
                ctx.log(f"Restored: {backup} -> {target}")
            reverted += 1

        ctx.log(f"Revert complete: {reverted} reverted, {skipped} skipped")

    def _latest_backup(self, target: Path) -> Path | None:
        index = 1
        last: Path | None = None
        while True:
            candidate = target.with_name(f"{target.name}.backup.{index}")
            if candidate.exists():
                last = candidate
                index += 1
            else:
                break
        return last
