from __future__ import annotations

import subprocess
from typing import Sequence


class CommandError(RuntimeError):
    pass


def run(
    cmd: Sequence[str] | str,
    *,
    shell: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    printable = cmd if isinstance(cmd, str) else " ".join(cmd)
    print(f"[cmd] {printable}")

    result = subprocess.run(
        cmd,
        shell=shell,
        text=True,
        capture_output=True,
        check=False,
    )

    if result.stdout.strip():
        print(result.stdout.strip())
    if result.stderr.strip():
        print(result.stderr.strip())

    if check and result.returncode != 0:
        raise CommandError(f"Command failed ({result.returncode}): {printable}")

    return result
