# Maintainer: whysooraj <whysooraj.official@gmail.com>
pkgname=tide-island-git
_pkgname=Tide-island
pkgver=r214.47c8f20
pkgrel=1
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
    'upower'
    'bluez'
    'bluez-utils'
    'quickshell'
)
makedepends=('cmake' 'git')
optdepends=(
    'cava: for audio visualizer'
    'imagemagick: for wallpaper thumbnails'
    'networkmanager: for wifi control'
    'iwd: for wifi control'
)
provides=('tide-island')
conflicts=('tide-island')
install='tide-island.install'
# We'll use the local files directly during the build function
source=("$_pkgname::git+https://github.com/enhaoswen/Tide-island.git")
sha256sums=('SKIP')

pkgver() {
  cd "$_pkgname"
  printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
  cmake -S "$_pkgname" -B build \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
  chmod +x "$pkgdir/usr/bin/tide-island"
  chmod +x "$pkgdir/usr/share/tide-island/bin/lyricsmpris"
}
