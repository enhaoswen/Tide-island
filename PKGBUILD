# Maintainer: whysooraj <whysooraj.official@gmail.com>
pkgname=tide-island
pkgver=1.0.13
pkgrel=1
_commit=106d38f4e1f4e683156564c1ae122ef7abc2a3cb
_srcdir=Tide-island-$_commit
pkgdesc="A dynamic island for Hyprland using Quickshell"
arch=('x86_64')
url="https://github.com/enhaoswen/Tide-island"
license=('unknown')
depends=(
    'qt6-base'
    'qt6-declarative'
    'qt6-connectivity'
    'qt6-svg'
    'hyprland'
    'wireplumber'
    'libpulse'
    'brightnessctl'
    'hyprsunset'
    'upower'
    'bluez'
    'bluez-utils'
    'quickshell'
)
makedepends=('cmake')
options=('!debug')
optdepends=(
    'cava: for audio visualizer'
    'imagemagick: for wallpaper thumbnails'
    'networkmanager: for wifi control'
    'iwd: for wifi control'
    'swaync: for the Focus do-not-disturb toggle'
)
conflicts=('tide-island-git')
install='tide-island.install'
source=("$pkgname-$_commit.tar.gz::https://github.com/enhaoswen/Tide-island/archive/$_commit.tar.gz")
sha256sums=('SKIP')

build() {
  cmake -S "$_srcdir" -B build \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
  chmod +x "$pkgdir/usr/bin/tide-island"
  chmod +x "$pkgdir/usr/share/tide-island/bin/lyricsmpris"
  chmod +x "$pkgdir/usr/share/tide-island/bin/tide-island-setup"
}
