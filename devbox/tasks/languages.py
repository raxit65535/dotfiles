from __future__ import annotations

import os
import stat
import tempfile
import urllib.request
from pathlib import Path

from utils.download import download_file, fetch_json
from utils.shell import run

from tasks.base import Context, Task


class LanguagesTask(Task):
    name = "languages"

    def run(self, ctx: Context) -> None:
        if ctx.enabled("python_pyenv"):
            self.install_pyenv(ctx)
        if ctx.enabled("golang"):
            self.install_go(ctx)
        if ctx.enabled("rust"):
            self.install_rust(ctx)
        if ctx.enabled("nodejs"):
            self.install_node(ctx)
        if ctx.enabled("java"):
            self.install_java(ctx)
        if ctx.enabled("postgres"):
            self.install_postgres(ctx)
        if ctx.enabled("google_cloud_sdk"):
            self.install_google_cloud_sdk(ctx)
        if ctx.enabled("bigdata"):
            self.install_bigdata(ctx)

    def install_pyenv(self, ctx: Context) -> None:
        pyenv_root = Path.home() / ".pyenv"
        if not pyenv_root.exists():
            run("curl -fsSL https://pyenv.run | bash", shell=True)

        # NOTE:
        # Add pyenv initialization to dotfiles/zsh/.zshrc.

    def install_go(self, ctx: Context) -> None:
        data = fetch_json("https://go.dev/dl/?mode=json")
        target_os = "darwin" if ctx.is_macos else "linux"
        target_arch = self.go_arch()

        chosen = None
        for release in data:
            if not isinstance(release, dict) or not release.get("stable"):
                continue
            for file_meta in release.get("files", []):
                if (
                    isinstance(file_meta, dict)
                    and file_meta.get("os") == target_os
                    and file_meta.get("arch") == target_arch
                    and file_meta.get("kind") == "archive"
                ):
                    chosen = {
                        "version": release["version"],
                        "filename": file_meta["filename"],
                    }
                    break
            if chosen:
                break

        if not chosen:
            raise RuntimeError("Could not find Go archive for this platform")

        version = chosen["version"].replace("go", "")
        root = Path.home() / ".local" / "go"
        version_dir = root / f"go{version}"
        current_link = root / "current"
        root.mkdir(parents=True, exist_ok=True)

        if not version_dir.exists():
            with tempfile.TemporaryDirectory() as td:
                archive = Path(td) / chosen["filename"]
                download_file(f"https://go.dev/dl/{chosen['filename']}", archive)
                version_dir.mkdir(parents=True, exist_ok=True)
                run(
                    [
                        "tar",
                        "-C",
                        str(version_dir),
                        "--strip-components=1",
                        "-xzf",
                        str(archive),
                    ]
                )

        if current_link.exists() or current_link.is_symlink():
            current_link.unlink()
        current_link.symlink_to(version_dir, target_is_directory=True)

        # NOTE:
        # zshrc should define GOROOT, GOPATH, and PATH.

    def install_rust(self, ctx: Context) -> None:
        rustup_bin = Path.home() / ".cargo" / "bin" / "rustup"
        if not rustup_bin.exists():
            run(
                "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
                shell=True,
            )

        # NOTE:
        # zshrc should add ~/.cargo/bin to PATH.

    def install_node(self, ctx: Context) -> None:
        nvm_dir = Path.home() / ".nvm"
        if not nvm_dir.exists():
            run(
                "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash",
                shell=True,
            )

        run(
            'export NVM_DIR="$HOME/.nvm"; '
            '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; '
            "nvm install --lts; "
            "nvm alias default 'lts/*'; "
            "npm install -g corepack pnpm yarn npm-check-updates",
            shell=True,
            check=False,
        )

        local_bin = Path.home() / ".local" / "bin"
        local_bin.mkdir(parents=True, exist_ok=True)

        helper = local_bin / "create-react-app-vite"
        helper.write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\nnpm create vite@latest "$@" -- --template react-ts\n',
            encoding="utf-8",
        )
        helper.chmod(helper.stat().st_mode | stat.S_IEXEC)

        # NOTE:
        # zshrc should load nvm and add ~/.local/bin to PATH.

    def install_java(self, ctx: Context) -> None:
        if ctx.is_macos:
            run(["brew", "install", "temurin"])
        else:
            run(["sudo", "apt-get", "install", "-y", "openjdk-21-jdk"])

    def install_postgres(self, ctx: Context) -> None:
        if ctx.is_macos:
            run(["brew", "install", "postgresql@16"])
            run(["brew", "services", "start", "postgresql@16"], check=False)
        else:
            run(
                [
                    "sudo",
                    "apt-get",
                    "install",
                    "-y",
                    "postgresql",
                    "postgresql-contrib",
                    "libpq-dev",
                ]
            )
            run(["sudo", "systemctl", "enable", "--now", "postgresql"], check=False)

    def install_google_cloud_sdk(self, ctx: Context) -> None:
        if ctx.is_macos:
            run(["brew", "install", "google-cloud-sdk"])
        else:
            run(
                "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg "
                "| sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg",
                shell=True,
            )
            run(
                'echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" '
                "| sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null",
                shell=True,
            )
            run(["sudo", "apt-get", "update"])
            run(["sudo", "apt-get", "install", "-y", "google-cloud-cli"])

    def install_bigdata(self, ctx: Context) -> None:
        import re

        bigdata_dir = ctx.bigdata_dir
        bigdata_dir.mkdir(parents=True, exist_ok=True)

        kafka_html = (
            urllib.request.urlopen("https://kafka.apache.org/downloads")
            .read()
            .decode("utf-8")
        )
        kafka_matches = re.findall(r"kafka_2\.13-\d+\.\d+\.\d+\.tgz", kafka_html)
        if not kafka_matches:
            raise RuntimeError("Could not determine latest Kafka version")
        kafka_file = sorted(set(kafka_matches))[-1]
        kafka_version = kafka_file.removeprefix("kafka_2.13-").removesuffix(".tgz")

        spark_html = (
            urllib.request.urlopen("https://spark.apache.org/downloads.html")
            .read()
            .decode("utf-8")
        )
        spark_matches = re.findall(r"Spark (\d+\.\d+\.\d+)", spark_html)
        if not spark_matches:
            raise RuntimeError("Could not determine latest Spark version")
        spark_version = spark_matches[0]
        spark_file = f"spark-{spark_version}-bin-hadoop3.tgz"

        items = [
            (
                f"https://downloads.apache.org/kafka/{kafka_version}/{kafka_file}",
                bigdata_dir / kafka_file,
                bigdata_dir / f"kafka_{kafka_version}",
            ),
            (
                f"https://downloads.apache.org/spark/spark-{spark_version}/{spark_file}",
                bigdata_dir / spark_file,
                bigdata_dir / f"spark_{spark_version}",
            ),
        ]

        for url, archive, dest in items:
            if not archive.exists():
                download_file(url, archive)
            if not dest.exists():
                dest.mkdir(parents=True, exist_ok=True)
                run(
                    [
                        "tar",
                        "-C",
                        str(dest),
                        "--strip-components=1",
                        "-xzf",
                        str(archive),
                    ]
                )

        # NOTE:
        # zshrc should set KAFKA_HOME, SPARK_HOME, and PATH.

    def go_arch(self) -> str:
        machine = os.uname().machine.lower()
        if machine in ("x86_64", "amd64"):
            return "amd64"
        if machine in ("arm64", "aarch64"):
            return "arm64"
        return machine
