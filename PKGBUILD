# Builds straight from this directory: run "makepkg -si" here.

pkgname=plasma-login-blur-slider
pkgver=1.0.0
pkgrel=1
pkgdesc='Blur intensity slider for the Plasma Login Manager login screen (no patching or rebuilding)'
arch=(any)
license=(GPL-3.0-or-later)
depends=(kconfig
         plasma-login-manager
         plasma-workspace)
install=$pkgname.install

package() {
  make -C "$startdir" DESTDIR="$pkgdir" PREFIX=/usr install install-alpm-hook
}
