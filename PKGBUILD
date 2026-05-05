# Maintainer: whysooraj <whysooraj.official@gmail.com>
pkgname=tide-island-git
_pkgname=Tide-island
pkgver=r95.4775fba
pkgrel=1
pkgdesc="A dynamic island for Hyprland using Quickshell"
arch=('x86_64')
url="https://github.com/sai21-learn/Tide-island"
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
source=("$_pkgname::git+https://github.com/sai21-learn/Tide-island.git")
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
}
