#!/usr/bin/env bash
#
# Build a SANE with the Mustek ScanExpress A3 USB 1200 Pro patch applied, on macOS.
# Produces a self-contained install tree in ./sane-install.
#
# Requirements (Homebrew):
#   brew install libusb autoconf automake libtool pkg-config autoconf-archive
#
# License: GPL-2.0-or-later
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${REPO_DIR}/build"
SRC_DIR="${WORK_DIR}/sane-backends"
INSTALL_DIR="${REPO_DIR}/sane-install"
PATCH="${REPO_DIR}/patches/0001-add-mustek-a3-usb-1200-pro.patch"

SANE_GIT="https://gitlab.com/sane-project/backends.git"
# Pin to the upstream commit the patch was generated against (see patches/UPSTREAM_BASE.txt).
SANE_BASE_COMMIT="ca8d120d3fb657c4e2a9efcd37fe662c1ca1a225"

# Homebrew prefix (arm64: /opt/homebrew, intel: /usr/local)
BREW_PREFIX="$(brew --prefix)"
ARCH="$(uname -m)"   # arm64 or x86_64

echo ">> Building patched SANE for macOS (${ARCH})"
echo ">> Homebrew prefix: ${BREW_PREFIX}"

# --- sanity: required tools ---
for t in git autoreconf automake libtool pkg-config; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t (brew install ...)"; exit 1; }
done
pkg-config --exists libusb-1.0 || { echo "libusb-1.0 not found (brew install libusb)"; exit 1; }
[ -f "${BREW_PREFIX}/share/aclocal/ax_cxx_compile_stdcxx.m4" ] || \
  { echo "autoconf-archive not found (brew install autoconf-archive)"; exit 1; }

mkdir -p "${WORK_DIR}"

# --- fetch upstream source at the pinned commit ---
if [ ! -d "${SRC_DIR}/.git" ]; then
  echo ">> Cloning upstream sane-backends"
  git clone "${SANE_GIT}" "${SRC_DIR}"
fi
cd "${SRC_DIR}"
git fetch --all --tags || true
git checkout -f "${SANE_BASE_COMMIT}" 2>/dev/null || {
  echo ">> Pinned commit not directly checkoutable (shallow?). Using current default branch HEAD."
}

# --- apply our patch (idempotent: reset tracked files first) ---
git checkout -- . 2>/dev/null || true
echo ">> Applying A3 1200 Pro patch"
git apply --check "${PATCH}" && git apply "${PATCH}"

# --- autotools needs a version, else V_MAJOR=UNKNOWN breaks libtool ---
[ -f .tarball-version ] || echo "1.4.0" > .tarball-version

export ACLOCAL_PATH="${BREW_PREFIX}/share/aclocal:${ACLOCAL_PATH:-}"
export PKG_CONFIG_PATH="${BREW_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

echo ">> autoreconf"
autoreconf -fi -I "${BREW_PREFIX}/share/aclocal"

echo ">> configure"
./configure \
  BACKENDS="mustek_usb2" \
  --disable-locking \
  --prefix="${INSTALL_DIR}" \
  CFLAGS="-O2 -arch ${ARCH}" \
  LDFLAGS="-arch ${ARCH}"

echo ">> make"
make
echo ">> make install"
make install

echo
echo ">> Done. Backend installed at: ${INSTALL_DIR}/lib/sane/"
echo ">> To use the freshly built tools:"
echo "     export SANE_CONFIG_DIR=\"${INSTALL_DIR}/etc/sane.d\""
echo "     export DYLD_LIBRARY_PATH=\"${INSTALL_DIR}/lib:${INSTALL_DIR}/lib/sane\""
echo "     ${INSTALL_DIR}/bin/sane-find-scanner"
echo "     ${INSTALL_DIR}/bin/scanimage -L"
