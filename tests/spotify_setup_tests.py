import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("spotify_setup", ROOT / "scripts/spotify-setup.py")
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SpotifySetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tide spotify test ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.spicetify_config = self.root / "spicetify/config-xpui.ini"
        self.spicetify_config.parent.mkdir()
        self.spicetify_config.write_text("[AdditionalOptions]\nextensions=existing-extension.js\n")
        self.bridge = self.root / "tide-island/spotify-bridge.json"
        self.extension = self.root / "spicetify/Extensions/tide-island.js"
        self.commands = []
        self.fail_apply = False

    def run_spicetify(self, command, **kwargs):
        self.commands.append(command)
        if command[1:] == ["-c"]:
            return subprocess.CompletedProcess(command, 0, stdout=str(self.spicetify_config) + "\n")
        if command[1:] == ["--version"]:
            return subprocess.CompletedProcess(command, 0, stdout="2.45.3\n")
        if command[1:3] == ["config", "extensions"]:
            text = self.spicetify_config.read_text()
            lines = text.splitlines(keepends=True)
            for index, line in enumerate(lines):
                if line.startswith("extensions="):
                    if command[-1].endswith("-"):
                        lines[index] = line.replace("|tide-island.js", "")
                    elif "|tide-island.js" not in line:
                        lines[index] = line.rstrip() + "|tide-island.js\n"
            self.spicetify_config.write_text("".join(lines))
        if "apply" in command and self.fail_apply:
            raise subprocess.CalledProcessError(1, command)
        return subprocess.CompletedProcess(command, 0)

    def run_setup(self, *arguments):
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(self.root)}), \
                patch.object(setup.os, "geteuid", return_value=1000), \
                patch.object(setup.shutil, "which", return_value="/fake bin/spicetify"), \
                patch.object(setup.subprocess, "run", side_effect=self.run_spicetify), \
                patch.object(setup.sys, "argv", ["spotify-setup", *arguments]):
            setup.main()

    def test_install_is_private_and_reuses_token_without_changing_other_extensions(self):
        self.run_setup("--no-apply", "--port", "9898")
        config = json.loads(self.bridge.read_text())
        self.assertEqual(config["port"], 9898)
        self.assertEqual(len(config["token"]), 64)
        self.assertEqual(self.bridge.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.extension.stat().st_mode & 0o777, 0o600)
        self.assertIn("ws://127.0.0.1:9898", self.extension.read_text())
        self.assertNotIn(setup.CONFIG_MARKER, self.extension.read_text())
        self.run_setup("--no-apply")
        self.assertEqual(json.loads(self.bridge.read_text()), config)
        self.assertIn("existing-extension.js", self.spicetify_config.read_text())
        self.assertTrue(all("apply" not in command for command in self.commands))

    def test_apply_failure_restores_all_previous_files(self):
        self.run_setup("--no-apply")
        before = {file: file.read_bytes() for file in (self.bridge, self.extension, self.spicetify_config)}
        self.fail_apply = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_setup("--port", "9899")
        for file, contents in before.items():
            self.assertEqual(file.read_bytes(), contents)

    def test_failed_fresh_install_removes_partial_configuration(self):
        before = self.spicetify_config.read_bytes()
        self.fail_apply = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_setup()
        self.assertFalse(self.bridge.exists())
        self.assertFalse(self.extension.exists())
        self.assertEqual(self.spicetify_config.read_bytes(), before)

    def test_failed_apply_preserves_symlinked_spicetify_configuration(self):
        target = self.root / "dotfiles-spicetify.ini"
        self.spicetify_config.rename(target)
        self.spicetify_config.symlink_to(target)
        before = target.read_bytes()
        self.fail_apply = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_setup()
        self.assertTrue(self.spicetify_config.is_symlink())
        self.assertEqual(target.read_bytes(), before)

    def test_remove_preserves_other_extensions(self):
        self.run_setup("--no-apply")
        self.run_setup("--remove", "--no-apply")
        self.assertFalse(self.bridge.exists())
        self.assertFalse(self.extension.exists())
        self.assertEqual(self.spicetify_config.read_text(), "[AdditionalOptions]\nextensions=existing-extension.js\n")

    def test_existing_backup_is_applied_without_backing_up_patched_assets(self):
        with self.spicetify_config.open("a") as output:
            output.write("[Backup]\nversion=1.2.96\nwith=2.45.3\n")
        self.run_setup()
        self.assertEqual(self.commands[-1][1:], ["apply"])

    def test_cli_upgrade_reprocesses_the_original_backup(self):
        with self.spicetify_config.open("a") as output:
            output.write("[Backup]\nversion=1.2.96\nwith=2.44.0\n")
        self.run_setup()
        self.assertEqual(self.commands[-1][1:], ["restore", "backup", "apply"])

    def test_repairs_invalid_existing_configuration(self):
        self.bridge.parent.mkdir()
        self.bridge.write_text("[]")
        self.run_setup("--no-apply")
        self.assertEqual(json.loads(self.bridge.read_text())["port"], 8976)


if __name__ == "__main__":
    unittest.main()
