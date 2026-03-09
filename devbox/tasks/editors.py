from __future__ import annotations

import tempfile
from pathlib import Path

from utils.download import download_file
from utils.shell import run

from tasks.base import Context, Task


class EditorsTask(Task):
    name = "editors"

    def run(self, ctx: Context) -> None:
        if (
            ctx.enabled("vscode")
            or ctx.enabled("intellij")
            or ctx.enabled("zed")
            or ctx.enabled("bruno")
        ):
            self.install_editors(ctx)

    def install_editors(self, ctx: Context) -> None:
        if ctx.is_macos:
            packages = []
            if ctx.enabled("vscode"):
                packages.append("visual-studio-code")
            if ctx.enabled("intellij"):
                packages.append("intellij-idea")
            if ctx.enabled("zed"):
                packages.append("zed")
            if ctx.enabled("bruno"):
                packages.append("bruno")

            if packages:
                run(["brew", "install", "--cask", *packages])
        else:
            if ctx.enabled("vscode"):
                with tempfile.TemporaryDirectory() as td:
                    deb = Path(td) / "code.deb"
                    download_file(
                        "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64",
                        deb,
                    )
                    run(["sudo", "apt-get", "install", "-y", str(deb)])

            if ctx.enabled("intellij"):
                run(
                    ["sudo", "snap", "install", "intellij-idea-ultimate", "--classic"],
                    check=False,
                )

            if ctx.enabled("zed"):
                run("curl -f https://zed.dev/install.sh | sh", shell=True, check=False)

            if ctx.enabled("bruno"):
                run(["sudo", "snap", "install", "bruno"], check=False)
