#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from tasks.base import BaseTask, Context
from tasks.browsers import BrowsersTask
from tasks.containers import ContainersTask
from tasks.dotfiles import DotfilesLinkTask
from tasks.editors import EditorsTask
from tasks.kubernetes import KubernetesTask
from tasks.languages import LanguagesTask


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Bootstrap a macOS or Ubuntu development machine."
    )
    parser.add_argument(
        "--config",
        default=str(Path(__file__).resolve().parent / "config.json"),
        help="Path to bootstrap config.json",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ctx = Context.from_config_file(Path(args.config).resolve())

    tasks = [
        BaseTask(),
        LanguagesTask(),
        ContainersTask(),
        KubernetesTask(),
        EditorsTask(),
        BrowsersTask(),
        DotfilesLinkTask(),
    ]

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
