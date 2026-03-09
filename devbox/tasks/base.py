from __future__ import annotations

import dataclasses
import json
import os
import platform
import shutil
from pathlib import Path

from utils.shell import run


@dataclasses.dataclass
class Context:
    repo_root: Path
    config_path: Path
    config: dict

    def log(self, msg: str) -> None:
        print(f"[devbox] {msg}")

    @classmethod
    def from_config_file(cls, config_path: Path) -> "Context":
        config = json.loads(config_path.read_text(encoding="utf-8"))
        repo_root = config_path.parent.parent.resolve()
        return cls(
            repo_root=repo_root,
            config_path=config_path,
            config=config,
        )

    @property
    def platform_name(self) -> str:
        system = platform.system().lower()
        if system == "darwin":
            return "macos"
        if system == "linux":
            return "ubuntu"
        raise RuntimeError(f"Unsupported platform: {platform.system()}")

    @property
    def is_macos(self) -> bool:
        return self.platform_name == "macos"

    @property
    def is_ubuntu(self) -> bool:
        return self.platform_name == "ubuntu"

    @property
    def machine_profile(self) -> str:
        return str(self.config.get("machine_profile", "global"))

    @property
    def home(self) -> Path:
        return Path.home()

    def resolve_path(self, raw: str) -> Path:
        return (self.config_path.parent / raw).expanduser().resolve()

    @property
    def dotfiles_root(self) -> Path:
        return self.resolve_path(self.config["dotfiles_root"])

    @property
    def bigdata_dir(self) -> Path:
        return Path(self.config["bigdata_dir"]).expanduser().resolve()

    def enabled(self, key: str) -> bool:
        return bool(self.config["install"].get(key, False))


class Task:
    name = "task"

    def run(self, ctx: Context) -> None:
        raise NotImplementedError


class BaseTask(Task):
    name = "base"

    def run(self, ctx: Context) -> None:
        self.install_core_packages(ctx)
        self.install_oh_my_zsh(ctx)

    def install_core_packages(self, ctx: Context) -> None:
        if ctx.is_macos:
            if not shutil.which("brew"):
                run(
                    '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
                    shell=True,
                )

            run(
                [
                    "brew",
                    "install",
                    "git",
                    "zsh",
                    "tmux",
                    "neovim",
                    "curl",
                    "wget",
                    "jq",
                    "ripgrep",
                    "fd",
                ]
            )
        else:
            run(["sudo", "apt-get", "update"])
            run(
                [
                    "sudo",
                    "apt-get",
                    "install",
                    "-y",
                    "build-essential",
                    "git",
                    "zsh",
                    "tmux",
                    "neovim",
                    "curl",
                    "wget",
                    "jq",
                    "ripgrep",
                    "fd-find",
                    "ca-certificates",
                    "gnupg",
                    "lsb-release",
                    "software-properties-common",
                    "unzip",
                    "zip",
                    "tar",
                    "xz-utils",
                    "pkg-config",
                    "make",
                    "gcc",
                    "g++",
                    "libssl-dev",
                    "zlib1g-dev",
                    "libbz2-dev",
                    "libreadline-dev",
                    "libsqlite3-dev",
                    "libffi-dev",
                    "liblzma-dev",
                    "tk-dev",
                ]
            )

    def install_oh_my_zsh(self, ctx: Context) -> None:
        if not ctx.enabled("oh_my_zsh"):
            return

        omz = ctx.home / ".oh-my-zsh"
        if not omz.exists():
            run(
                'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"',
                shell=True,
            )

        theme_source = (
            ctx.dotfiles_root / "shell" / "themes" / "custom_robbyrussell.zsh-theme"
        )
        if theme_source.exists():
            dest_dir = omz / "custom" / "themes"
            dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(theme_source, dest_dir / theme_source.name)

        if ctx.is_ubuntu:
            zsh_path = shutil.which("zsh") or "/usr/bin/zsh"
            if os.environ.get("SHELL") != zsh_path:
                run(["chsh", "-s", zsh_path], check=False)

        # NOTE:
        # Do not modify ~/.zshrc here.
        # Keep shell setup in dotfiles/shell/.zshrc.
