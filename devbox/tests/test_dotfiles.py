from __future__ import annotations

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tasks.base import Context
from tasks.dotfiles import DotfilesLinkTask, DotfilesRevertTask


class DotfilesTaskTests(unittest.TestCase):
    def test_backup_path_treats_broken_symlink_as_occupied(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            target = tmp / "managed-config"
            broken_backup = target.with_name(f"{target.name}.backup.1")
            broken_backup.symlink_to(tmp / "missing-backup")

            backup = DotfilesLinkTask()._backup_path(target)

            self.assertEqual(target.with_name(f"{target.name}.backup.2"), backup)

    def test_latest_backup_includes_broken_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            target = tmp / "managed-config"
            latest_backup = target.with_name(f"{target.name}.backup.1")
            latest_backup.symlink_to(tmp / "missing-backup")

            backup = DotfilesRevertTask()._latest_backup(target)

            self.assertEqual(latest_backup, backup)

    def test_revert_skips_when_current_symlink_points_elsewhere(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            repo_root = tmp / "repo"
            repo_root.mkdir()
            (repo_root / "managed-config").mkdir()

            devbox_dir = repo_root / "devbox"
            devbox_dir.mkdir()
            config_path = devbox_dir / "config.json"
            config_path.write_text("{}", encoding="utf-8")

            current_source = tmp / "other-config"
            current_source.mkdir()

            target = tmp / "config" / "managed-config"
            target.parent.mkdir(parents=True)
            target.symlink_to(current_source, target_is_directory=True)

            backup = target.with_name(f"{target.name}.backup.1")
            backup.mkdir()

            ctx = Context(
                repo_root=repo_root,
                config_path=config_path,
                config={
                    "dotfiles_root": "..",
                    "symlinks": [
                        {
                            "name": "managed-config",
                            "source": "managed-config",
                            "target": str(target),
                        }
                    ],
                },
            )

            output = io.StringIO()
            with redirect_stdout(output):
                DotfilesRevertTask().run(ctx)

            self.assertTrue(target.is_symlink())
            self.assertEqual(current_source.resolve(), target.resolve(strict=False))
            self.assertTrue(backup.exists())
            self.assertIn(
                "Skipping revert 'managed-config': current symlink points to",
                output.getvalue(),
            )


if __name__ == "__main__":
    unittest.main()
