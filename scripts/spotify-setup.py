#!/usr/bin/env python3
"""Install/remove Tide Island's local Spicetify bridge for the current user."""

import argparse
import configparser
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tempfile

EXTENSION_NAME = "tide-island.js"
CONFIG_MARKER = "/* TIDE_ISLAND_CONFIG */ null"


def atomic_write(destination, data, mode=0o600):
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(dir=destination.parent, prefix=".tide-island-")
    try:
        with os.fdopen(descriptor, "wb") as output:
            os.fchmod(output.fileno(), mode)
            output.write(data)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def extension_source():
    script = Path(__file__).resolve()
    for candidate in (
        script.parent.parent / "integrations/spicetify" / EXTENSION_NAME,
        script.parent.parent / "share/tide-island/spicetify" / EXTENSION_NAME,
    ):
        if candidate.is_file():
            return candidate
    raise RuntimeError("The Spicetify extension is missing. Reinstall Tide Island.")


def activation_command(spicetify, config_file):
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.read(config_file)
    if not config.get("Backup", "version", fallback=""):
        return [spicetify, "backup", "apply"]
    result = subprocess.run([spicetify, "--version"], check=True, text=True, capture_output=True, timeout=10)
    if config.get("Backup", "with", fallback="") != result.stdout.strip().removeprefix("v"):
        # Reprocess the stock backup when Spicetify was upgraded. Backing up an
        # already-patched Spotify installation directly is rejected by the CLI.
        return [spicetify, "restore", "backup", "apply"]
    return [spicetify, "apply"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, help="Local bridge port (default: 8976, or the existing port)")
    parser.add_argument("--no-apply", action="store_true", help="Prepare files; run spicetify apply yourself afterward")
    parser.add_argument("--remove", action="store_true", help="Remove only the Tide Island extension and bridge configuration")
    options = parser.parse_args()
    if options.port is not None and not 1024 <= options.port <= 65535:
        parser.error("--port must be between 1024 and 65535")
    if os.geteuid() == 0:
        raise RuntimeError("Run this command as your desktop user, without sudo.")
    spicetify = shutil.which("spicetify")
    if not spicetify:
        raise RuntimeError("Spicetify is not installed. Install it from https://spicetify.app/docs/getting-started first.")

    result = subprocess.run([spicetify, "-c"], check=True, text=True, capture_output=True, timeout=10)
    config_file = Path(result.stdout.strip())
    if not config_file.is_absolute() or not config_file.is_file():
        raise RuntimeError("Spicetify is not configured. Open Spotify once, then run spicetify to initialize it.")
    extension_file = config_file.parent / "Extensions" / EXTENSION_NAME
    config_root = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    bridge_file = config_root / "tide-island/spotify-bridge.json"

    snapshots = {}
    # Restore the real INI file if the user's Spicetify config is a dotfiles symlink.
    for target in (config_file.resolve(), extension_file, bridge_file):
        snapshots[target] = (target.read_bytes(), target.stat().st_mode & 0o777) if target.exists() else None
    try:
        if options.remove:
            subprocess.run([spicetify, "config", "extensions", EXTENSION_NAME + "-"], check=True, timeout=15)
            extension_file.unlink(missing_ok=True)
            bridge_file.unlink(missing_ok=True)
        else:
            template = extension_source().read_text()
            if template.count(CONFIG_MARKER) != 1:
                raise RuntimeError("The bundled Spicetify extension is invalid. Reinstall Tide Island.")
            existing = {}
            if bridge_file.exists():
                try:
                    existing = json.loads(bridge_file.read_text())
                    if not isinstance(existing, dict):
                        existing = {}
                except (ValueError, OSError):
                    pass
            port = options.port if options.port is not None else existing.get("port", 8976)
            if not isinstance(port, int) or isinstance(port, bool) or not 1024 <= port <= 65535:
                port = 8976
            token = existing.get("token", "")
            if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{64}", token):
                token = secrets.token_hex(32)
            config = {"version": 1, "port": port, "token": token}
            extension_config = {**config, "endpoint": f"ws://127.0.0.1:{port}"}
            atomic_write(extension_file, template.replace(CONFIG_MARKER, json.dumps(extension_config)).encode())
            atomic_write(bridge_file, (json.dumps(config, indent=2) + "\n").encode())
            subprocess.run([spicetify, "config", "extensions", EXTENSION_NAME], check=True, timeout=15)
        if not options.no_apply:
            command = activation_command(spicetify, config_file)
            subprocess.run(command, check=True, timeout=120)
    except (Exception, KeyboardInterrupt):
        for target, snapshot in snapshots.items():
            if snapshot is None:
                target.unlink(missing_ok=True)
            else:
                atomic_write(target, *snapshot)
        print("Setup failed; restored the previous configuration and extension files.", file=sys.stderr)
        raise

    if options.remove:
        print("Tide Island's Spotify favorites extension was removed.")
    else:
        print("Spotify favorites bridge installed. Start Tide Island and Spotify.")
    if options.no_apply:
        command = "tide-island-spotify-setup --remove" if options.remove else "tide-island-spotify-setup"
        print(f"Run {command} to activate these changes.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
