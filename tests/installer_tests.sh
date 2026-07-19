#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

write_os_release() {
  local name="$1"
  local id="$2"
  local id_like="$3"
  cat > "$TMP_DIR/$name" <<EOF
ID=$id
ID_LIKE="$id_like"
VERSION_ID=testing
EOF
}

run_case() {
  local name="$1"
  local expected="$2"
  local dbus_package="$3"
  local extra_package="${4:-}"
  local output
  output="$(
    TIDE_INSTALLER_OS_RELEASE="$TMP_DIR/$name" \
      TIDE_INSTALLER_QT_VERSION="6.8.0" \
      "$ROOT/install.sh" \
        --dry-run \
        --force-build-quickshell \
        --no-service \
        --force \
        --yes
  )"
  grep -Fq -- "$expected" <<< "$output"
  grep -Fq -- "$ROOT" <<< "$output"
  grep -Fq -- "59e9c47b0eb48a9e4bcf9631fa062ee939bd2e83" <<< "$output"
  grep -Fq -- "-DCMAKE_INSTALL_PREFIX=/usr" <<< "$output"
  grep -Fq -- "$dbus_package" <<< "$output"
  [[ -z "$extra_package" ]] || grep -Fq -- "$extra_package" <<< "$output"
}

run_failure_case() {
  local name="$1"
  local qt_version="$2"
  local expected="$3"
  shift 3
  local output
  if output="$(
    TIDE_INSTALLER_OS_RELEASE="$TMP_DIR/$name" \
      TIDE_INSTALLER_QT_VERSION="$qt_version" \
      "$ROOT/install.sh" --dry-run --yes "$@" 2>&1
  )"; then
    printf 'Expected installer failure for %s, but it succeeded.\n' "$name" >&2
    exit 1
  fi
  grep -Fq -- "$expected" <<< "$output"
}

bash -n "$ROOT/install.sh"
"$ROOT/install.sh" --help >/dev/null

write_os_release ubuntu ubuntu debian
write_os_release fedora fedora "rhel fedora"
write_os_release opensuse opensuse-tumbleweed suse
write_os_release arch arch arch
write_os_release unknown void ""

run_case ubuntu "apt-get install" " dbus "
run_case fedora "sudo dnf install" " dbus-daemon " " cli11-devel "
run_case opensuse "sudo zypper --non-interactive install" " dbus-1 "
run_failure_case arch "6.8.0" "Arch-based systems should install" --force
run_failure_case unknown "6.8.0" "unsupported distribution 'void'" --force
run_failure_case ubuntu "6.4.2" "Qt 6.4.2 is too old" --skip-deps --force

if "$ROOT/install.sh" --dry-run --skip-quickshell --force-build-quickshell >/dev/null 2>&1; then
  printf 'Conflicting Quickshell options unexpectedly succeeded.\n' >&2
  exit 1
fi

printf 'Installer tests passed.\n'
