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
        target = Path(target_raw).expanduser().resolve()

        if not source.exists():
            raise FileNotFoundError(f"Symlink source does not exist: {source}")

        target.parent.mkdir(parents=True, exist_ok=True)

        if target.is_symlink():
            existing = target.resolve()
            if existing == source:
                ctx.log(f"Symlink already correct: {target} -> {source}")
                return
            target.unlink()

        elif target.exists():
            backup = self._backup_path(target)
            ctx.log(f"Backing up existing target: {target} -> {backup}")
            shutil.move(str(target), str(backup))

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
