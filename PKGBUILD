# Maintainer: whysooraj <whysooraj.official@gmail.com>
pkgname=tide-island
pkgver=1.0.15
pkgrel=1
_srcdir=Tide-island-$pkgver
pkgdesc="A dynamic island for Hyprland using Quickshell"
arch=('x86_64')
url="https://github.com/enhaoswen/Tide-island"
license=('unknown')
depends=(
    'qt6-base'
    'qt6-declarative'
    'qt6-wayland'
    'qt6-connectivity'
    'qt6-svg'
    'hyprland'
    'wireplumber'
    'pipewire'
    'dbus'
    'libpulse'
    'systemd-libs'
    'brightnessctl'
    'hyprsunset'
    'upower'
    'bluez'
    'bluez-utils'
    'quickshell'
)
makedepends=('cmake')
options=('!debug' '!strip')
optdepends=(
    'cava: for audio visualizer'
    'imagemagick: for wallpaper thumbnails'
    'awww: for applying wallpapers from the wallpaper picker'
    'networkmanager: for wifi control'
    'iwd: for wifi control'
    'swaync: for the Focus do-not-disturb toggle'
    'tlp: for TLP power profile controls'
    'polkit: for applying TLP profiles via pkexec'
    'sudo: alternative for applying TLP profiles'
)
conflicts=('tide-island-git')
install='tide-island.install'
source=("$pkgname-$pkgver.tar.gz::https://github.com/enhaoswen/Tide-island/archive/refs/tags/$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
  cmake -S "$_srcdir" -B build \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
  rm -f "$pkgdir/usr/lib/qt6/qml/TideIsland/tide-island-config-app_qml_module_dir_map.qrc"
  chmod +x "$pkgdir/usr/bin/tide-island"
  chmod +x "$pkgdir/usr/bin/tide-island-config-app"
  chmod +x "$pkgdir/usr/share/tide-island/bin/lyricsmpris"
}
