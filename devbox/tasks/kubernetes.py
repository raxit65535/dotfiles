from __future__ import annotations

import os
import tempfile
import urllib.request
from pathlib import Path

from utils.download import download_file
from utils.shell import run

from tasks.base import Context, Task


class KubernetesTask(Task):
    name = "kubernetes"

    def run(self, ctx: Context) -> None:
        if not ctx.enabled("kubernetes"):
            return

        if ctx.is_macos:
            self.install_macos(ctx)
        else:
            self.install_ubuntu(ctx)

        self.configure_minikube(ctx)

    def install_macos(self, ctx: Context) -> None:
        run(["brew", "install", "kubectl", "helm", "minikube", "k9s"])

        # NOTE:
        # Put aliases/completions like alias k=kubectl in dotfiles/zsh/.zshrc if desired.

    def install_ubuntu(self, ctx: Context) -> None:
        stable = self._latest_kubectl_release()
        arch = self._linux_arch()

        with tempfile.TemporaryDirectory() as td:
            tmp_dir = Path(td)

            kubectl_bin = tmp_dir / "kubectl"
            download_file(
                f"https://dl.k8s.io/release/{stable}/bin/linux/{arch}/kubectl",
                kubectl_bin,
                mode=0o755,
            )
            run(
                [
                    "sudo",
                    "install",
                    "-o",
                    "root",
                    "-g",
                    "root",
                    "-m",
                    "0755",
                    str(kubectl_bin),
                    "/usr/local/bin/kubectl",
                ]
            )

            run(
                "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",
                shell=True,
            )

            minikube_bin = tmp_dir / "minikube"
            download_file(
                f"https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-{arch}",
                minikube_bin,
                mode=0o755,
            )
            run(["sudo", "install", str(minikube_bin), "/usr/local/bin/minikube"])

            run(
                'bash -c "$(curl -fsSL https://webinstall.dev/k9s)"',
                shell=True,
                check=False,
            )

        # NOTE:
        # Shell completion and aliases should live in dotfiles/zsh/.zshrc.

    def configure_minikube(self, ctx: Context) -> None:
        run(["minikube", "config", "set", "driver", "docker"], check=False)

    def _latest_kubectl_release(self) -> str:
        return (
            urllib.request.urlopen("https://dl.k8s.io/release/stable.txt")
            .read()
            .decode()
            .strip()
        )

    def _linux_arch(self) -> str:
        machine = os.uname().machine.lower()
        if machine in ("x86_64", "amd64"):
            return "amd64"
        if machine in ("arm64", "aarch64"):
            return "arm64"
        return machine
