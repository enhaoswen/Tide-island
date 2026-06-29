#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
PREFIX="/usr"
SKIP_QUICKSHELL=0
FORCE_BUILD_QUICKSHELL=0
ENABLE_SERVICE=1

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
  upower
  bluez
)

OPTIONAL_PACKAGES=(
  cava
  imagemagick
  awww
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
Disable Waybar or any other top bar that reserves the same top screen area before
using Tide Island. Also choose one startup method: systemd --user or Hyprland
exec-once, but not both.
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
  enable_service
  print_top_bar_note
  print_final_commands
}

main "$@"
