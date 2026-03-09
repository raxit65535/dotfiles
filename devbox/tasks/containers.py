from __future__ import annotations

import os

from utils.shell import run

from tasks.base import Context, Task


class ContainersTask(Task):
    name = "containers"

    def run(self, ctx: Context) -> None:
        if not ctx.enabled("containers"):
            return

        if ctx.is_macos:
            self.install_macos(ctx)
        else:
            self.install_ubuntu(ctx)

    def install_macos(self, ctx: Context) -> None:
        run(["brew", "install", "docker", "docker-compose", "colima"])
        run(
            ["colima", "start", "--cpu", "4", "--memory", "8", "--disk", "100"],
            check=False,
        )

        # NOTE:
        # Keep aliases and env setup in dotfiles/zsh/.zshrc if needed.

    def install_ubuntu(self, ctx: Context) -> None:
        run(["sudo", "install", "-m", "0755", "-d", "/etc/apt/keyrings"])

        run(
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | "
            "sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
            shell=True,
        )

        arch = self._docker_arch()
        repo_line = (
            f"deb [arch={arch} signed-by=/etc/apt/keyrings/docker.gpg] "
            "https://download.docker.com/linux/ubuntu "
            '$(. /etc/os-release && echo "$VERSION_CODENAME") stable'
        )

        run(
            f'echo "{repo_line}" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null',
            shell=True,
        )

        run(["sudo", "apt-get", "update"])
        run(
            [
                "sudo",
                "apt-get",
                "install",
                "-y",
                "docker-ce",
                "docker-ce-cli",
                "containerd.io",
                "docker-buildx-plugin",
                "docker-compose-plugin",
            ]
        )

        user = os.environ.get("USER")
        if user:
            run(["sudo", "usermod", "-aG", "docker", user], check=False)

        # NOTE:
        # User may need to log out and back in for docker group membership to apply.

    def _docker_arch(self) -> str:
        machine = os.uname().machine.lower()
        if machine in ("x86_64", "amd64"):
            return "amd64"
        if machine in ("arm64", "aarch64"):
            return "arm64"
        return machine
