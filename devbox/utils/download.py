from __future__ import annotations

import json
import shutil
import urllib.request
from pathlib import Path


def download_file(url: str, destination: Path, mode: int | None = None) -> None:
    """
    Download a file from a URL to the given destination.

    Responsibilities:
    - create parent directories if needed
    - write file contents
    - optionally chmod the file after download
    """
    destination.parent.mkdir(parents=True, exist_ok=True)
    print(f"[download] {url} -> {destination}")

    with urllib.request.urlopen(url) as response, destination.open("wb") as file_handle:
        shutil.copyfileobj(response, file_handle)

    if mode is not None:
        destination.chmod(mode)


def fetch_json(url: str):
    """
    Fetch JSON from a URL and return the parsed object.
    """
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read().decode("utf-8"))
