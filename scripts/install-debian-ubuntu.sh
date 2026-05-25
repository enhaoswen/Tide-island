#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
PREFIX="/usr"
SKIP_QUICKSHELL=0
FORCE_BUILD_QUICKSHELL=0
ENABLE_SERVICE=1
APPLY_DESKTOP_INTEGRATION=1
DISABLE_WAYBAR=1
MUTE_SWAYNC=1
INSTALL_TOGGLE_BIND=1
SKIP_SETUP_WIZARD=1

REQUIRED_PACKAGES=(
  git
  build-essential
  cmake
  ninja-build
  pkg-config
  qt6-base-dev
  qt6-base-private-dev
  qt6-declarative-dev
  qt6-declarative-private-dev
  qt6-wayland
  qt6-wayland-dev
  qt6-wayland-private-dev
  qt6-shadertools-dev
  libqt6svg6
  libqt6svg6-dev
  libudev-dev
  libdrm-dev
  libwayland-dev
  wayland-protocols
  libgbm-dev
  vulkan-headers
  libjemalloc-dev
  libcli11-dev
  spirv-tools
  hyprland
  wireplumber
  pulseaudio-utils
  brightnessctl
  dbus-bin
  python3
  upower
  bluez
)

OPTIONAL_PACKAGES=(
  cava
  imagemagick
  network-manager
)

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Install Tide Island on Debian/Ubuntu-like systems.

Options:
  --skip-quickshell        Assume Quickshell is already installed.
  --force-build-quickshell Build Quickshell even if quickshell is already in PATH.
  --no-enable-service      Install only; do not enable or start the systemd user service.
  --no-desktop-integration Do not change Waybar, SwayNC, Hyprland keybinds, or setup wizard behavior.
  --no-disable-waybar      Do not disable Waybar services or Hyprland exec-once entries.
  --no-mute-swaync         Do not mute SwayNC notification popups.
  --no-toggle-bind         Do not install the Ctrl+Super+Alt+B Tide Island toggle keybind.
  --keep-setup-wizard      Do not set TIDE_ISLAND_SKIP_SETUP=1 in the user service override.
  --prefix DIR             Install prefix. Currently only /usr is supported.
  -h, --help               Show this help message.
EOF
}

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while (($#)); do
    case "$1" in
      --skip-quickshell)
        SKIP_QUICKSHELL=1
        ;;
      --force-build-quickshell)
        FORCE_BUILD_QUICKSHELL=1
        ;;
      --no-enable-service)
        ENABLE_SERVICE=0
        ;;
      --no-desktop-integration)
        APPLY_DESKTOP_INTEGRATION=0
        ;;
      --no-disable-waybar)
        DISABLE_WAYBAR=0
        ;;
      --no-mute-swaync)
        MUTE_SWAYNC=0
        ;;
      --no-toggle-bind)
        INSTALL_TOGGLE_BIND=0
        ;;
      --keep-setup-wizard)
        SKIP_SETUP_WIZARD=0
        ;;
      --prefix)
        shift
        [[ $# -gt 0 ]] || die "--prefix requires a directory"
        PREFIX="$1"
        ;;
      --prefix=*)
        PREFIX="${1#*=}"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

require_debian_ubuntu_environment() {
  command -v apt-get >/dev/null 2>&1 || die "apt-get was not found. This installer is for Debian/Ubuntu-like systems."
  command -v apt-cache >/dev/null 2>&1 || die "apt-cache was not found. Install apt tooling before running this installer."
  command -v sudo >/dev/null 2>&1 || die "sudo was not found. Install sudo or run the commands manually."

  if [[ "$PREFIX" != "/usr" ]]; then
    die "custom prefixes are not supported yet. Tide Island's launcher and systemd service currently expect /usr."
  fi
}

repo_root() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  cd -- "$script_dir/.." >/dev/null 2>&1
  pwd
}

package_available() {
  local package="$1"
  apt-cache show "$package" >/dev/null 2>&1
}

install_apt_dependencies() {
  log "Refreshing apt metadata"
  sudo -v
  sudo apt-get update

  local missing_required=()
  local package
  for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! package_available "$package"; then
      missing_required+=("$package")
    fi
  done

  if ((${#missing_required[@]} > 0)); then
    printf 'Missing required apt packages in your enabled repositories:\n' >&2
    printf '  %s\n' "${missing_required[@]}" >&2
    die "enable the needed Debian/Ubuntu repositories, backports, PPAs, or install equivalent packages first."
  fi

  log "Installing required dependencies"
  sudo apt-get install -y "${REQUIRED_PACKAGES[@]}"

  local available_optional=()
  local missing_optional=()
  for package in "${OPTIONAL_PACKAGES[@]}"; do
    if package_available "$package"; then
      available_optional+=("$package")
    else
      missing_optional+=("$package")
    fi
  done

  if ((${#available_optional[@]} > 0)); then
    log "Installing optional feature packages"
    sudo apt-get install -y "${available_optional[@]}"
  fi

  if ((${#missing_optional[@]} > 0)); then
    warn "optional packages not found in enabled repositories: ${missing_optional[*]}"
  fi
  warn "If your Wi-Fi stack uses iwd instead of NetworkManager, install iwd separately."
}

check_qt_version() {
  if ! command -v qtpaths6 >/dev/null 2>&1; then
    warn "qtpaths6 was not found after dependency installation; Quickshell may fail to build."
    return
  fi

  local version major minor
  version="$(qtpaths6 --qt-version 2>/dev/null || true)"
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"

  if [[ -z "$version" || ! "$major" =~ ^[0-9]+$ || ! "$minor" =~ ^[0-9]+$ ]]; then
    warn "could not determine Qt version; Quickshell requires Qt 6.6 or newer."
    return
  fi

  if ((major < 6 || (major == 6 && minor < 6))); then
    die "Qt $version is too old. Quickshell requires Qt 6.6 or newer."
  fi
}

build_quickshell() {
  if ((SKIP_QUICKSHELL)); then
    log "Skipping Quickshell build because --skip-quickshell was passed"
    return
  fi

  if command -v quickshell >/dev/null 2>&1 && ((FORCE_BUILD_QUICKSHELL == 0)); then
    log "Quickshell is already installed: $(command -v quickshell)"
    return
  fi

  local cache_base quickshell_dir
  cache_base="${XDG_CACHE_HOME:-$HOME/.cache}/tide-island-installer"
  quickshell_dir="$cache_base/quickshell"
  mkdir -p "$cache_base"

  if [[ -d "$quickshell_dir/.git" ]]; then
    log "Updating Quickshell source"
    git -C "$quickshell_dir" pull --ff-only
  elif [[ -e "$quickshell_dir" ]]; then
    die "$quickshell_dir exists but is not a git checkout. Move it aside and rerun this script."
  else
    log "Cloning Quickshell source"
    git clone --depth 1 https://git.outfoxxed.me/quickshell/quickshell.git "$quickshell_dir"
  fi

  log "Configuring Quickshell"
  cmake -GNinja -S "$quickshell_dir" -B "$quickshell_dir/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCRASH_HANDLER=OFF \
    -DX11=OFF \
    -DSERVICE_PIPEWIRE=OFF \
    -DSERVICE_PAM=OFF \
    -DSERVICE_POLKIT=OFF

  log "Building Quickshell"
  cmake --build "$quickshell_dir/build"

  log "Installing Quickshell"
  sudo cmake --install "$quickshell_dir/build"

  if command -v quickshell >/dev/null 2>&1; then
    quickshell --version || true
  else
    warn "quickshell is still not in PATH. Make sure $PREFIX/bin is available in your session."
  fi
}

build_tide_island() {
  local root
  root="$(repo_root)"

  log "Configuring Tide Island"
  cmake -S "$root" -B "$root/build-debian-ubuntu" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"

  log "Building Tide Island"
  cmake --build "$root/build-debian-ubuntu"

  log "Installing Tide Island"
  sudo cmake --install "$root/build-debian-ubuntu"
}

timestamp() {
  date +%Y%m%d-%H%M%S
}

backup_file() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  cp -p "$path" "$path.tide-island.bak.$(timestamp)"
}

systemctl_user_exists() {
  systemctl --user list-unit-files "$1" --no-legend 2>/dev/null | grep -q .
}

disable_waybar_conflicts() {
  ((APPLY_DESKTOP_INTEGRATION && DISABLE_WAYBAR)) || return 0

  log "Disabling Waybar conflicts when present"

  if systemctl_user_exists waybar.service; then
    systemctl --user disable --now waybar.service >/dev/null 2>&1 || warn "could not disable user waybar.service"
  fi

  if systemctl_user_exists waybar-autohide.service; then
    systemctl --user disable --now waybar-autohide.service >/dev/null 2>&1 || warn "could not disable user waybar-autohide.service"
  fi

  sudo systemctl --global disable waybar.service >/dev/null 2>&1 || true
  sudo systemctl --global disable waybar-autohide.service >/dev/null 2>&1 || true

  local hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  [[ -d "$hypr_dir" ]] || return 0

  python3 - "$hypr_dir" <<'PY'
import pathlib
import re
import shutil
import sys
import time

root = pathlib.Path(sys.argv[1])
pattern = re.compile(r'^(\s*)exec-once\s*=\s*waybar(?:\s.*)?$', re.IGNORECASE)

for path in root.rglob("*.conf"):
    try:
        text = path.read_text()
    except UnicodeDecodeError:
        continue

    changed = False
    out = []
    for line in text.splitlines(keepends=True):
        line_body = line.rstrip("\n")
        newline = "\n" if line.endswith("\n") else ""
        if not line_body.lstrip().startswith("#") and pattern.match(line_body):
            out.append("# Tide Island replaces Waybar as the top bar." + newline)
            out.append("# " + line_body + newline)
            changed = True
        else:
            out.append(line)

    if changed:
        backup = path.with_name(path.name + ".tide-island.bak." + time.strftime("%Y%m%d-%H%M%S"))
        shutil.copy2(path, backup)
        path.write_text("".join(out))
        print(f"commented Waybar exec-once in {path}")
PY
}

mute_swaync_popups() {
  ((APPLY_DESKTOP_INTEGRATION && MUTE_SWAYNC)) || return 0

  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/swaync"
  local config="$config_dir/config.json"
  [[ -f "$config" ]] || {
    warn "SwayNC config was not found; skipping SwayNC popup mute"
    return 0
  }

  log "Muting SwayNC notification popups to avoid duplicate Tide Island notifications"
  backup_file "$config"

  if ! python3 - "$config" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
with path.open() as f:
    data = json.load(f)

visibility = data.setdefault("notification-visibility", {})
visibility["tide-island-handles-popups"] = {
    "state": "muted",
    "app-name": ".*",
}

path.write_text(json.dumps(data, indent=2) + "\n")
PY
  then
    warn "could not update SwayNC config; leaving it unchanged"
    return 0
  fi

  systemctl --user restart swaync.service >/dev/null 2>&1 || true
}

install_toggle_keybind() {
  ((APPLY_DESKTOP_INTEGRATION && INSTALL_TOGGLE_BIND)) || return 0

  local hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  [[ -d "$hypr_dir" ]] || {
    warn "Hyprland config directory was not found; skipping Tide Island toggle keybind"
    return 0
  }

  log "Installing Ctrl+Super+Alt+B Tide Island toggle keybind"

  local scripts_dir="$hypr_dir/scripts"
  local script="$scripts_dir/TideIslandToggle.sh"
  mkdir -p "$scripts_dir"
  cat >"$script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if systemctl --user is-active --quiet tide-island.service; then
  systemctl --user stop tide-island.service
else
  systemctl --user start tide-island.service
fi
EOF
  chmod +x "$script"

  local keybind_file="$hypr_dir/configs/Keybinds.conf"
  [[ -f "$keybind_file" ]] || keybind_file="$hypr_dir/hyprland.conf"
  backup_file "$keybind_file"

  python3 - "$keybind_file" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text() if path.exists() else ""

variables = {}
for line in text.splitlines():
    stripped = line.split("#", 1)[0].strip()
    if stripped.startswith("$") and "=" in stripped:
        name, value = stripped.split("=", 1)
        variables[name.strip()] = value.strip()

def resolves_to_super(token):
    token = token.strip()
    return token.upper() == "SUPER" or variables.get(token, "").upper() == "SUPER"

def is_toggle_combo(line):
    stripped = line.lstrip()
    if stripped.startswith("#") or not stripped.lower().startswith("bind"):
        return False
    if "=" not in line:
        return False
    rhs = line.split("=", 1)[1]
    parts = [part.strip() for part in rhs.split(",")]
    if len(parts) < 2 or parts[1].upper() != "B":
        return False
    mods = re.split(r"[\s+|]+", parts[0])
    upper_mods = {mod.upper() for mod in mods if mod}
    has_super = any(resolves_to_super(mod) for mod in mods if mod)
    return has_super and {"CTRL", "ALT"}.issubset(upper_mods)

changed = False
out = []
for line in text.splitlines(keepends=True):
    body = line.rstrip("\n")
    newline = "\n" if line.endswith("\n") else ""
    if is_toggle_combo(body) and "TideIslandToggle.sh" not in body:
        out.append("# Replaced by Tide Island toggle.\n")
        out.append("# " + body + newline)
        changed = True
    else:
        out.append(line)

if changed:
    path.write_text("".join(out))
PY

  if ! grep -Eq 'TideIslandToggle\.sh|toggle tide island on/off' "$keybind_file"; then
    cat >>"$keybind_file" <<EOF

# Tide Island toggle
bindd = \$mainMod CTRL ALT, B, toggle tide island on/off, exec, $script
EOF
  fi

  hyprctl reload >/dev/null 2>&1 || true
}

configure_setup_wizard_behavior() {
  ((APPLY_DESKTOP_INTEGRATION && SKIP_SETUP_WIZARD)) || return 0

  log "Configuring service override to avoid repeatedly opening the setup wizard"
  local override_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/tide-island.service.d"
  mkdir -p "$override_dir"
  cat >"$override_dir/10-skip-setup.conf" <<'EOF'
[Service]
Environment=TIDE_ISLAND_SKIP_SETUP=1
EOF

  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

apply_desktop_integration() {
  ((APPLY_DESKTOP_INTEGRATION)) || {
    log "Skipping desktop integration changes"
    return 0
  }

  disable_waybar_conflicts
  mute_swaync_popups
  install_toggle_keybind
  configure_setup_wizard_behavior
}

enable_service() {
  if ((ENABLE_SERVICE == 0)); then
    log "Skipping systemd user service enablement because --no-enable-service was passed"
    return
  fi

  log "Reloading and enabling the Tide Island user service"
  systemctl --user daemon-reload
  systemctl --user enable --now tide-island
}

print_top_bar_note() {
  cat <<'EOF'

==> Top bar note
This installer can disable common Waybar startup paths, mute SwayNC popups, add
a Tide Island service toggle keybind, and set the service to skip the setup
wizard after installation. If you manage those pieces yourself, rerun with
--no-desktop-integration or one of the narrower --no-* options.
EOF
}

print_final_commands() {
  cat <<'EOF'

==> Useful commands
  systemctl --user restart tide-island
  systemctl --user stop tide-island
  journalctl --user -u tide-island -f
  tide-island-setup --wizard
EOF
}

main() {
  parse_args "$@"
  require_debian_ubuntu_environment
  install_apt_dependencies
  check_qt_version
  build_quickshell
  build_tide_island
  apply_desktop_integration
  enable_service
  print_top_bar_note
  print_final_commands
}

main "$@"
