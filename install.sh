#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly PREFIX="/usr"
readonly STATE_DIR="/var/lib/tide-island"
readonly INSTALL_MANIFEST="$STATE_DIR/install-manifest.txt"
readonly QUICKSHELL_BUILD_INFO="$STATE_DIR/quickshell-source-build.txt"
readonly QUICKSHELL_REPOSITORY="https://git.outfoxxed.me/quickshell/quickshell.git"
readonly QUICKSHELL_MIRROR="https://github.com/quickshell-mirror/quickshell.git"
readonly QUICKSHELL_VERSION="v0.3.0"
readonly QUICKSHELL_COMMIT="59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83"

INSTALL_DEPENDENCIES=1
QUICKSHELL_MODE="auto"
QUICKSHELL_SKIP_REQUESTED=0
QUICKSHELL_FORCE_REQUESTED=0
ENABLE_SERVICE=1
UNINSTALL=0
DRY_RUN=0
ASSUME_YES=0
FORCE=0
SERVICE_WAS_ACTIVE=0

restore_service_after_error() {
  local status=$?
  trap - ERR
  if ((SERVICE_WAS_ACTIVE)) && command -v systemctl >/dev/null 2>&1; then
    systemctl --user start tide-island.service >/dev/null 2>&1 || true
  fi
  exit "$status"
}

trap restore_service_after_error ERR

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

print_command() {
  printf '  +'
  printf ' %q' "$@"
  printf '\n'
}

run() {
  if ((DRY_RUN)); then
    print_command "$@"
    return 0
  fi
  "$@"
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Build and install Tide Island from source to /usr.
Run this script as a regular desktop user; it requests sudo when needed.

Options:
  --skip-deps             Do not install distribution packages.
  --skip-quickshell       Require an existing /usr/bin/quickshell.
  --force-build-quickshell
                          Rebuild the pinned Quickshell version.
  --no-service            Do not enable or start the systemd user service.
  --uninstall             Remove the source-installed Tide Island files.
  --dry-run               Print actions without changing the system.
  --force                 Allow Arch/source-package conflicts and overwrite.
  -y, --yes               Do not ask for confirmation.
  -h, --help              Show this help.

Supported dependency installers: apt, dnf, and zypper.
For other Linux distributions, install dependencies yourself and use --skip-deps.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --skip-deps)
        INSTALL_DEPENDENCIES=0
        ;;
      --skip-quickshell)
        QUICKSHELL_MODE="skip"
        QUICKSHELL_SKIP_REQUESTED=1
        ;;
      --force-build-quickshell)
        QUICKSHELL_MODE="force"
        QUICKSHELL_FORCE_REQUESTED=1
        ;;
      --no-service)
        ENABLE_SERVICE=0
        ;;
      --uninstall)
        UNINSTALL=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --force)
        FORCE=1
        ;;
      -y|--yes)
        ASSUME_YES=1
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

  if ((QUICKSHELL_SKIP_REQUESTED && QUICKSHELL_FORCE_REQUESTED)); then
    die "--skip-quickshell and --force-build-quickshell cannot be used together"
  fi

}

repo_root() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  [[ -f "$script_dir/CMakeLists.txt" ]] || die "CMakeLists.txt was not found next to $SCRIPT_NAME"
  printf '%s\n' "$script_dir"
}

load_os_release() {
  local os_release="${TIDE_INSTALLER_OS_RELEASE:-/etc/os-release}"
  [[ -r "$os_release" ]] || die "cannot read $os_release"

  ID=""
  ID_LIKE=""
  VERSION_ID=""
  # /etc/os-release is the standard shell-compatible distribution metadata file.
  # shellcheck disable=SC1090
  source "$os_release"
  ID="${ID,,}"
  ID_LIKE=" ${ID_LIKE,,} "

  case "$ID" in
    debian|ubuntu|linuxmint|pop|elementary|zorin)
      DISTRO_FAMILY="apt"
      ;;
    fedora|rhel|centos|rocky|almalinux|ultramarine|nobara)
      DISTRO_FAMILY="dnf"
      ;;
    opensuse*|sles)
      DISTRO_FAMILY="zypper"
      ;;
    arch|endeavouros|manjaro|cachyos|garuda)
      DISTRO_FAMILY="arch"
      ;;
    *)
      if [[ "$ID_LIKE" == *" debian "* || "$ID_LIKE" == *" ubuntu "* ]]; then
        DISTRO_FAMILY="apt"
      elif [[ "$ID_LIKE" == *" fedora "* || "$ID_LIKE" == *" rhel "* ]]; then
        DISTRO_FAMILY="dnf"
      elif [[ "$ID_LIKE" == *" suse "* ]]; then
        DISTRO_FAMILY="zypper"
      elif [[ "$ID_LIKE" == *" arch "* ]]; then
        DISTRO_FAMILY="arch"
      else
        DISTRO_FAMILY="unknown"
      fi
      ;;
  esac
}

confirm() {
  ((ASSUME_YES || DRY_RUN)) && return 0
  [[ -t 0 ]] || die "confirmation requires a terminal; rerun with --yes"
  printf 'Install Tide Island to /usr on %s %s? [y/N] ' "$ID" "${VERSION_ID:-}"
  local answer
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || die "installation canceled"
}

require_regular_user() {
  if ((EUID == 0 && !DRY_RUN)); then
    die "run this installer as your regular desktop user, not as root"
  fi
  if ((!DRY_RUN)); then
    command -v sudo >/dev/null 2>&1 || die "sudo is required for the fixed /usr installation"
  fi
}

sudo_init() {
  ((DRY_RUN)) && return 0
  sudo -v
}

package_install_conflict() {
  ((FORCE || DRY_RUN)) && return 0

  if command -v pacman >/dev/null 2>&1 && pacman -Q tide-island >/dev/null 2>&1; then
    die "the pacman/AUR tide-island package is installed; update it with your AUR helper instead (or use --force)"
  fi
  if command -v dpkg-query >/dev/null 2>&1 \
      && dpkg-query -W -f='${Status}' tide-island 2>/dev/null | grep -q 'install ok installed'; then
    die "a dpkg-managed tide-island package is installed; remove it first (or use --force)"
  fi
  if command -v rpm >/dev/null 2>&1 && rpm -q tide-island >/dev/null 2>&1; then
    die "an RPM-managed tide-island package is installed; remove it first (or use --force)"
  fi
}

apt_install_dependencies() {
  local packages=(
    git build-essential cmake ninja-build pkg-config
    qt6-base-dev qt6-base-private-dev
    qt6-declarative-dev qt6-declarative-private-dev
    qml6-module-qt5compat-graphicaleffects
    qt6-wayland qt6-wayland-dev qt6-wayland-private-dev
    qt6-shadertools-dev libqt6svg6 libqt6svg6-dev
    libudev-dev libdrm-dev libwayland-dev wayland-protocols
    libgbm-dev vulkan-headers libjemalloc-dev libcli11-dev spirv-tools
    wireplumber pulseaudio-utils brightnessctl dbus upower bluez
    policykit-1 zenity network-manager
  )

  log "Installing Debian/Ubuntu build and runtime dependencies"
  run sudo apt-get update
  if ((DRY_RUN)); then
    run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
    return
  fi

  local available=()
  local missing=()
  local package
  for package in "${packages[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
      available+=("$package")
    else
      missing+=("$package")
    fi
  done
  ((${#available[@]} > 0)) \
    && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${available[@]}"
  ((${#missing[@]} == 0)) \
    || warn "packages unavailable in enabled apt repositories: ${missing[*]}"
}

dnf_install_dependencies() {
  local packages=(
    git gcc-c++ cmake ninja-build pkgconf-pkg-config
    qt6-qtbase-devel qt6-qtbase-private-devel
    qt6-qtdeclarative-devel qt6-qtwayland-devel
    qt6-qt5compat
    qt6-qtshadertools-devel qt6-qtsvg-devel
    systemd-devel libdrm-devel wayland-devel wayland-protocols-devel
    mesa-libgbm-devel vulkan-headers jemalloc-devel cli11-devel spirv-tools-devel
    wireplumber pulseaudio-utils brightnessctl dbus-daemon upower bluez bluez-tools
    polkit zenity NetworkManager
  )

  log "Installing Fedora/RHEL build and runtime dependencies"
  if ((DRY_RUN)); then
    run sudo dnf install -y "${packages[@]}"
    return
  fi

  local available=()
  local missing=()
  local package
  for package in "${packages[@]}"; do
    if rpm -q "$package" >/dev/null 2>&1 || dnf -q list "$package" >/dev/null 2>&1; then
      available+=("$package")
    else
      missing+=("$package")
    fi
  done
  ((${#available[@]} > 0)) && sudo dnf install -y "${available[@]}"
  ((${#missing[@]} == 0)) \
    || warn "packages unavailable in enabled dnf repositories: ${missing[*]}"
}

zypper_install_dependencies() {
  local packages=(
    git gcc-c++ cmake ninja pkg-config
    qt6-base-devel qt6-declarative-devel qt6-wayland-devel
    qt6-qt5compat-imports
    qt6-shadertools-devel qt6-svg-devel
    systemd-devel libdrm-devel wayland-devel wayland-protocols-devel
    Mesa-libgbm-devel vulkan-headers libjemalloc-devel cli11-devel spirv-tools-devel
    wireplumber pulseaudio-utils brightnessctl dbus-1 upower bluez
    polkit zenity NetworkManager
  )

  log "Installing openSUSE build and runtime dependencies"
  if ((DRY_RUN)); then
    run sudo zypper --non-interactive install --no-recommends "${packages[@]}"
    return
  fi

  local available=()
  local missing=()
  local package
  for package in "${packages[@]}"; do
    if rpm -q "$package" >/dev/null 2>&1 \
        || zypper --xmlout --non-interactive search --match-exact --type package "$package" 2>/dev/null \
          | grep -Fq "name=\"$package\""; then
      available+=("$package")
    else
      missing+=("$package")
    fi
  done
  ((${#available[@]} > 0)) \
    && sudo zypper --non-interactive install --no-recommends "${available[@]}"
  ((${#missing[@]} == 0)) \
    || warn "packages unavailable in enabled zypper repositories: ${missing[*]}"
}

install_dependencies() {
  ((INSTALL_DEPENDENCIES)) || {
    log "Skipping distribution dependency installation"
    return
  }

  case "$DISTRO_FAMILY" in
    apt)
      apt_install_dependencies
      ;;
    dnf)
      dnf_install_dependencies
      ;;
    zypper)
      zypper_install_dependencies
      ;;
    arch)
      die "Arch-based systems should install Tide Island with the AUR package; use --skip-deps --force only for development"
      ;;
    *)
      die "unsupported distribution '$ID'; install dependencies manually and rerun with --skip-deps"
      ;;
  esac
}

qt_version() {
  local version=""
  if [[ -n "${TIDE_INSTALLER_QT_VERSION:-}" ]]; then
    printf '%s\n' "$TIDE_INSTALLER_QT_VERSION"
    return
  fi
  if command -v pkg-config >/dev/null 2>&1; then
    version="$(pkg-config --modversion Qt6Core 2>/dev/null || true)"
  fi
  if [[ -z "$version" ]] && command -v qtpaths6 >/dev/null 2>&1; then
    version="$(qtpaths6 --qt-version 2>/dev/null || true)"
  fi
  if [[ -z "$version" && -x /usr/lib/qt6/bin/qtpaths6 ]]; then
    version="$(/usr/lib/qt6/bin/qtpaths6 --qt-version 2>/dev/null || true)"
  fi
  printf '%s\n' "$version"
}

version_at_least() {
  local current="$1"
  local minimum="$2"
  [[ "$(printf '%s\n%s\n' "$minimum" "$current" | sort -V | head -n1)" == "$minimum" ]]
}

verify_build_tools() {
  local missing=()
  local command
  for command in cmake ninja git pkg-config; do
    command -v "$command" >/dev/null 2>&1 || missing+=("$command")
  done
  ((${#missing[@]} == 0)) || die "missing build tools: ${missing[*]}"

  local version
  version="$(qt_version)"
  [[ -n "$version" ]] || die "Qt 6 development files were not detected"
  version_at_least "$version" "6.6.0" \
    || die "Qt $version is too old; Tide Island's pinned Quickshell requires Qt 6.6 or newer"
  log "Detected Qt $version"
}

installer_cache_dir() {
  printf '%s/tide-island-installer\n' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

prepare_quickshell_source() {
  local source_dir="$1"
  if [[ -d "$source_dir/.git" ]]; then
    if ! run git -C "$source_dir" fetch --depth 1 origin "$QUICKSHELL_COMMIT"; then
      warn "cached Quickshell remote failed; switching to the official mirror"
      run git -C "$source_dir" remote set-url origin "$QUICKSHELL_MIRROR"
      run git -C "$source_dir" fetch --depth 1 origin "$QUICKSHELL_COMMIT"
    fi
  elif [[ -e "$source_dir" ]]; then
    die "$source_dir exists but is not a Quickshell git checkout"
  else
    mkdir -p "$(dirname "$source_dir")"
    run git init -q "$source_dir"
    run git -C "$source_dir" remote add origin "$QUICKSHELL_REPOSITORY"
    if ! run git -C "$source_dir" fetch --depth 1 origin "$QUICKSHELL_COMMIT"; then
      warn "primary Quickshell repository failed; trying the official mirror"
      run git -C "$source_dir" remote set-url origin "$QUICKSHELL_MIRROR"
      run git -C "$source_dir" fetch --depth 1 origin "$QUICKSHELL_COMMIT"
    fi
  fi
  run git -C "$source_dir" checkout --detach "$QUICKSHELL_COMMIT"

  if ((!DRY_RUN)); then
    local actual_commit
    actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
    [[ "$actual_commit" == "$QUICKSHELL_COMMIT" ]] \
      || die "Quickshell checkout verification failed"
  fi
}

build_quickshell() {
  if [[ "$QUICKSHELL_MODE" == "skip" ]]; then
    [[ -x /usr/bin/quickshell || $DRY_RUN -eq 1 ]] \
      || die "--skip-quickshell requires /usr/bin/quickshell"
    log "Using the existing /usr/bin/quickshell"
    return
  fi

  if [[ -x /usr/bin/quickshell && "$QUICKSHELL_MODE" != "force" ]]; then
    local current_qt recorded_qt
    current_qt="$(qt_version)"
    recorded_qt=""
    if [[ -r "$QUICKSHELL_BUILD_INFO" ]]; then
      recorded_qt="$(sed -n 's/^qt=//p' "$QUICKSHELL_BUILD_INFO" | head -n1)"
    fi
    if [[ -z "$recorded_qt" || "$recorded_qt" == "$current_qt" ]]; then
      log "Using the existing /usr/bin/quickshell"
      /usr/bin/quickshell --version 2>/dev/null || true
      return
    fi
    warn "Qt changed from $recorded_qt to $current_qt; rebuilding the source-installed Quickshell"
  fi

  local cache_dir source_dir build_dir
  cache_dir="$(installer_cache_dir)"
  source_dir="$cache_dir/quickshell-$QUICKSHELL_VERSION"
  build_dir="$source_dir/build-tide-island"

  log "Preparing pinned Quickshell $QUICKSHELL_VERSION ($QUICKSHELL_COMMIT)"
  if ((DRY_RUN)); then
    print_command git clone "$QUICKSHELL_REPOSITORY" "$source_dir"
  else
    prepare_quickshell_source "$source_dir"
  fi

  log "Building Quickshell"
  run cmake -GNinja -S "$source_dir" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DDISTRIBUTOR="Tide Island source installer" \
    -DCRASH_HANDLER=OFF \
    -DX11=OFF \
    -DSERVICE_PIPEWIRE=OFF \
    -DSERVICE_PAM=OFF \
    -DSERVICE_POLKIT=OFF
  run cmake --build "$build_dir" --parallel
  run sudo cmake --install "$build_dir"
  if ((!DRY_RUN)); then
    local build_info
    build_info="$(mktemp)"
    printf 'version=%s\ncommit=%s\nqt=%s\n' \
      "$QUICKSHELL_VERSION" "$QUICKSHELL_COMMIT" "$(qt_version)" > "$build_info"
    sudo install -d -m 0755 "$STATE_DIR"
    sudo install -m 0644 "$build_info" "$QUICKSHELL_BUILD_INFO"
    rm -f "$build_info"
  else
    print_command sudo install -m 0644 quickshell-source-build.txt "$QUICKSHELL_BUILD_INFO"
  fi

  [[ -x /usr/bin/quickshell || $DRY_RUN -eq 1 ]] \
    || die "Quickshell installation did not create /usr/bin/quickshell"
}

remove_manifest_files() {
  [[ -f "$INSTALL_MANIFEST" ]] || return 0

  log "Removing files from the previous source installation"
  local paths=()
  mapfile -t paths < "$INSTALL_MANIFEST"
  local index path
  for ((index=${#paths[@]} - 1; index >= 0; --index)); do
    path="${paths[index]}"
    [[ "$path" == /usr/* ]] || die "unsafe path in $INSTALL_MANIFEST: $path"
    run sudo rm -f -- "$path"
  done
}

remove_obsolete_manifest_files() {
  local previous_manifest="$1"
  local next_manifest="$2"
  [[ -f "$previous_manifest" ]] || return 0

  log "Removing obsolete files from the previous Tide Island version"
  local path
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$path" == /usr/* ]] || die "unsafe path in previous install manifest: $path"
    grep -Fqx -- "$path" "$next_manifest" || run sudo rm -f -- "$path"
  done < "$previous_manifest"
}

build_tide_island() {
  local root cache_dir build_dir
  root="$(repo_root)"
  cache_dir="$(installer_cache_dir)"
  build_dir="$root/build-release-installer"
  mkdir -p "$cache_dir"

  log "Configuring Tide Island"
  run cmake -U CMAKE_INSTALL_LIBDIR -GNinja -S "$root" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
  run cmake --build "$build_dir" --parallel
  run ctest --test-dir "$build_dir" --output-on-failure

  if systemctl --user is-active --quiet tide-island.service 2>/dev/null; then
    SERVICE_WAS_ACTIVE=1
    run systemctl --user stop tide-island.service
  fi

  local previous_manifest="$cache_dir/previous-install-manifest.txt"
  if [[ -r "$INSTALL_MANIFEST" ]]; then
    cp "$INSTALL_MANIFEST" "$previous_manifest"
  else
    : > "$previous_manifest"
  fi

  log "Installing Tide Island to /usr"
  run sudo cmake --install "$build_dir"
  if ((!DRY_RUN)); then
    remove_obsolete_manifest_files "$previous_manifest" "$build_dir/install_manifest.txt"
  fi
  run sudo install -d -m 0755 "$STATE_DIR"
  run sudo install -m 0644 "$build_dir/install_manifest.txt" "$INSTALL_MANIFEST"
}

configure_service() {
  if ((ENABLE_SERVICE == 0)); then
    log "Skipping systemd user service setup"
    if ((SERVICE_WAS_ACTIVE)); then
      run systemctl --user start tide-island.service
      SERVICE_WAS_ACTIVE=0
    fi
    return
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl was not found; start Tide Island manually with /usr/bin/tide-island"
    return
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "a systemd user session is not available; start Tide Island manually with /usr/bin/tide-island"
    return
  fi

  log "Enabling and starting the Tide Island user service"
  run systemctl --user daemon-reload
  run systemctl --user enable --now tide-island.service
  SERVICE_WAS_ACTIVE=0
}

uninstall_tide_island() {
  require_regular_user
  sudo_init
  [[ -f "$INSTALL_MANIFEST" || $DRY_RUN -eq 1 ]] \
    || die "no source installation manifest was found at $INSTALL_MANIFEST"

  if command -v systemctl >/dev/null 2>&1; then
    run systemctl --user disable --now tide-island.service || true
  fi
  remove_manifest_files
  run sudo rm -f -- "$INSTALL_MANIFEST"
  run sudo rmdir --ignore-fail-on-non-empty "$STATE_DIR"
  command -v systemctl >/dev/null 2>&1 && run systemctl --user daemon-reload || true
  log "Tide Island was removed. Quickshell and distribution dependencies were left installed."
}

main() {
  parse_args "$@"
  load_os_release

  if ((UNINSTALL)); then
    uninstall_tide_island
    return
  fi

  require_regular_user
  package_install_conflict
  confirm
  sudo_init
  install_dependencies
  verify_build_tools
  build_quickshell
  build_tide_island
  configure_service
  SERVICE_WAS_ACTIVE=0

  log "Tide Island installation completed"
  printf '  Config app: /usr/bin/tide-island-config-app\n'
  printf '  Logs:       journalctl --user -u tide-island -f\n'
  printf '  Uninstall:  ./%s --uninstall\n' "$SCRIPT_NAME"
}

main "$@"
