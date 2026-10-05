# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds straight from this directory: run "makepkg -si" here.
#
# The version is not maintained in this file. pkgver() takes it from the
# release tag, or in a release tarball from its VERSION file; see
# scripts/version.sh. "make package" builds in a copy and leaves this file
# alone.

pkgname=plasma-login-blur-slider
pkgver=0.0.0
pkgrel=1
pkgdesc='Blur intensity and style for the Plasma login screen and lock screen (no patching or rebuilding)'
arch=(any)
# url=  (set this to the repository's address)
license=(GPL-3.0-or-later)
depends=(bash
         kconfig
         plasma-login-manager
         plasma-workspace)
install=$pkgname.install

pkgver() {
  "$startdir/scripts/version.sh"
}

package() {
  make -C "$startdir" VERSION="$pkgver" DESTDIR="$pkgdir" PREFIX=/usr install install-alpm-hook
}
