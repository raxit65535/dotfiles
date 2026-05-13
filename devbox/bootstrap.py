#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from tasks.base import BaseTask, Context, Task
from tasks.browsers import BrowsersTask
from tasks.containers import ContainersTask
from tasks.dotfiles import DotfilesLinkTask, DotfilesRevertTask
from tasks.editors import EditorsTask
from tasks.kubernetes import KubernetesTask
from tasks.languages import LanguagesTask


def build_install_tasks() -> list[Task]:
    return [
        BaseTask(),
        LanguagesTask(),
        ContainersTask(),
        KubernetesTask(),
        EditorsTask(),
        BrowsersTask(),
    ]


def build_tasks(mode: str) -> list[Task]:
    install_tasks = build_install_tasks()
    symlink_task = DotfilesLinkTask()

    if mode == "all":
        return [*install_tasks, symlink_task]
    if mode == "install":
        return install_tasks
    if mode == "symlinks":
        return [symlink_task]
    if mode == "revert":
        return [DotfilesRevertTask()]
    raise ValueError(f"Unknown mode: {mode}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Bootstrap a macOS or Ubuntu development machine."
    )
    parser.add_argument(
        "--config",
        default=str(Path(__file__).resolve().parent / "config.json"),
        help="Path to bootstrap config.json",
    )
    parser.add_argument(
        "--mode",
        choices=["all", "install", "symlinks", "revert"],
        default="all",
        help="Task mode: all (install + symlinks), install (install only), symlinks (link dotfiles only), revert (restore backups and remove symlinks)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview symlink actions without writing files (only valid with --mode symlinks)",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ctx = Context.from_config_file(Path(args.config).resolve())

    if args.dry_run and args.mode not in ("symlinks", "revert"):
        raise RuntimeError("--dry-run is only supported with --mode symlinks or --mode revert")

    if args.dry_run:
        ctx.config["dry_run"] = True

    tasks = build_tasks(args.mode)
    ctx.log(f"Selected mode: {args.mode}")
    if args.dry_run:
        ctx.log("Dry run enabled: no filesystem changes will be made")

    for task in tasks:
        ctx.log(f"==> Running task: {task.name}")
        task.run(ctx)

    ctx.log("Bootstrap finished.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        raise SystemExit(130)
