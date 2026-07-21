#!/usr/bin/env python3

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PICKER_QML = REPOSITORY_ROOT / "qml/island/WallpaperPickerLayer.qml"
SETTINGS_QML = REPOSITORY_ROOT / "Tide-island-app/Wallpaper.qml"


def extract_apply_script():
    qml = PICKER_QML.read_text(encoding="utf-8")
    match = re.search(
        r"readonly property string applyScript:\s*(.*?)\n\s*readonly property var transitionTypes:",
        qml,
        re.DOTALL,
    )
    if not match:
        raise AssertionError("Could not find applyScript in WallpaperPickerLayer.qml")

    fragments = re.findall(r'"(?:[^"\\]|\\.)*"', match.group(1))
    return "".join(json.loads(fragment) for fragment in fragments)


class WallpaperApplyTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.bin_directory = self.root / "bin"
        self.bin_directory.mkdir()
        self.log_path = self.root / "commands.log"
        self.source_path = self.root / "source image.jpg"
        self.source_path.write_bytes(b"wallpaper")
        self.apply_script = extract_apply_script()

        self.write_fake_command(
            "awww",
            """#!/bin/sh
printf 'awww' >> "$WALLPAPER_TEST_LOG"
for argument in "$@"; do printf '\\t%s' "$argument" >> "$WALLPAPER_TEST_LOG"; done
printf '\\n' >> "$WALLPAPER_TEST_LOG"
exit "${AWWW_EXIT_CODE:-0}"
""",
        )
        self.write_fake_command(
            "wal",
            """#!/bin/sh
printf 'wal' >> "$WALLPAPER_TEST_LOG"
for argument in "$@"; do printf '\\t%s' "$argument" >> "$WALLPAPER_TEST_LOG"; done
printf '\\n' >> "$WALLPAPER_TEST_LOG"
exit "${WAL_EXIT_CODE:-0}"
""",
        )

    def write_fake_command(self, name, contents):
        path = self.bin_directory / name
        path.write_text(contents, encoding="utf-8")
        path.chmod(0o755)

    def run_apply(self, *, source=None, target="", pywal=True, extra_environment=None):
        environment = os.environ.copy()
        environment.update(
            {
                "HOME": str(self.root),
                "PATH": str(self.bin_directory) + os.pathsep + environment.get("PATH", ""),
                "WALLPAPER_TEST_LOG": str(self.log_path),
            }
        )
        if extra_environment:
            environment.update(extra_environment)

        arguments = [
            str(source or self.source_path),
            target,
            "center",
            "5",
            "3",
            "60",
            "45",
            "center",
            ".54,0,.34,.99",
            "20,20",
            "false",
            "true" if pywal else "false",
        ]
        return subprocess.run(
            [sys.executable, "-c", self.apply_script, *arguments],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def command_log(self):
        if not self.log_path.exists():
            return []
        return self.log_path.read_text(encoding="utf-8").splitlines()

    def test_builtin_flow_runs_pywal_after_awww(self):
        target_path = self.root / "target" / "current.jpg"

        result = self.run_apply(target=str(target_path))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target_path.read_bytes(), self.source_path.read_bytes())
        commands = self.command_log()
        self.assertEqual(len(commands), 2)
        self.assertTrue(commands[0].startswith(f"awww\timg\t{target_path}\t"))
        self.assertEqual(commands[1], f"wal\t-n\t-q\t-i\t{self.source_path}")

    def test_stable_target_uses_each_selected_source_for_pywal(self):
        target_path = self.root / "target" / "current.png"
        second_source = self.root / "second wallpaper.png"
        second_source.write_bytes(b"second wallpaper")

        first_result = self.run_apply(source=self.source_path, target=str(target_path))
        second_result = self.run_apply(source=second_source, target=str(target_path))

        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        self.assertEqual(second_result.returncode, 0, second_result.stderr)
        wal_commands = [line for line in self.command_log() if line.startswith("wal\t")]
        self.assertEqual(
            wal_commands,
            [
                f"wal\t-n\t-q\t-i\t{self.source_path}",
                f"wal\t-n\t-q\t-i\t{second_source}",
            ],
        )

    def test_failed_wallpaper_command_does_not_run_pywal(self):
        result = self.run_apply(extra_environment={"AWWW_EXIT_CODE": "7"})

        self.assertEqual(result.returncode, 7)
        self.assertEqual(len(self.command_log()), 1)
        self.assertTrue(self.command_log()[0].startswith("awww\t"))

    def test_missing_pywal_command_is_reported(self):
        (self.bin_directory / "wal").unlink()

        result = self.run_apply(extra_environment={"PATH": str(self.bin_directory)})

        self.assertEqual(result.returncode, 127)
        self.assertIn("the 'wal' command was not found in PATH", result.stderr)

    def test_custom_command_disables_builtin_settings(self):
        qml = SETTINGS_QML.read_text(encoding="utf-8")

        self.assertEqual(qml.count("blocked: root.customCommandActive"), 3)
        self.assertIn("enabled: !root.customCommandActive", qml)
        self.assertIn("blocked: !root.customCommandActive", qml)


if __name__ == "__main__":
    unittest.main()
