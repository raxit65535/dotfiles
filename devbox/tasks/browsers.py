from __future__ import annotations

import tempfile
from pathlib import Path

from utils.download import download_file
from utils.shell import run

from tasks.base import Context, Task


class BrowsersTask(Task):
    name = "browsers"

    def run(self, ctx: Context) -> None:
        self.install_browsers(ctx)
        self.install_communication_apps(ctx)

    def install_browsers(self, ctx: Context) -> None:
        if not ctx.enabled("browsers"):
            return

        if ctx.is_macos:
            run(
                [
                    "brew",
                    "install",
                    "--cask",
                    "google-chrome",
                    "firefox",
                    "brave-browser",
                ]
            )
        else:
            self.install_ubuntu_browsers(ctx)

    def install_communication_apps(self, ctx: Context) -> None:
        if ctx.is_macos:
            if ctx.enabled("zoom") or ctx.enabled("iterm2"):
                packages = []
                if ctx.enabled("zoom"):
                    packages.append("zoom")
                if ctx.enabled("iterm2"):
                    packages.append("iterm2")

                if packages:
                    run(["brew", "install", "--cask", *packages])
        else:
            if ctx.enabled("zoom"):
                self.install_ubuntu_zoom(ctx)

    def install_ubuntu_browsers(self, ctx: Context) -> None:
        run(["sudo", "snap", "install", "firefox"], check=False)

        with tempfile.TemporaryDirectory() as td:
            chrome_deb = Path(td) / "google-chrome.deb"
            download_file(
                "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
                chrome_deb,
            )
            run(["sudo", "apt-get", "install", "-y", str(chrome_deb)])

        run(
            "curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg "
            "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg",
            shell=True,
        )

        run(
            'echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] '
            'https://brave-browser-apt-release.s3.brave.com/ stable main" | '
            "sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null",
            shell=True,
        )

        run(["sudo", "apt-get", "update"])
        run(["sudo", "apt-get", "install", "-y", "brave-browser"])

    def install_ubuntu_zoom(self, ctx: Context) -> None:
        with tempfile.TemporaryDirectory() as td:
            zoom_deb = Path(td) / "zoom.deb"
            download_file("https://zoom.us/client/latest/zoom_amd64.deb", zoom_deb)
            run(["sudo", "apt-get", "install", "-y", str(zoom_deb)])
