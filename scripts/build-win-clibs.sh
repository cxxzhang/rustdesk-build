#!/usr/bin/env bash
# Build the four C static libraries the RustDesk Windows client links against:
# libyuv, opus, libaom, libvpx.
#
# These must be:
#   - built for x86_64-pc-windows-msvc
#   - static CRT (/MT), no /GL (whole-program optimisation) —
#     /GL emits intermediate code the MSVC linker will not accept from a static lib
#   - installed where vcpkg.json points, so `build.py` finds them
#
# This mirrors what the project did by hand. It is the most fragile step in the
# whole pipeline; expect to iterate on the first run.
set -euo pipefail

PREFIX="${WIN_CLIBS_PREFIX:-$HOME/.cache/andesk-win-clibs}"
JOBS="$(nproc)"
mkdir -p "$PREFIX"

echo "== installing into $PREFIX (jobs=$JOBS)"

# --- libyuv ---------------------------------------------------------------
build_libyuv() {
  [ -f "$PREFIX/lib/yuv.lib" ] && { echo "== libyuv present"; return; }
  echo "== libyuv"
  local d=/tmp/libyuv
  git clone --depth 1 https://chromium.googlesource.com/libyuv/libyuv "$d"
  cmake -S "$d" -B "$d/build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF
  cmake --build "$d/build" -j "$JOBS"
  cmake --install "$d/build"
}

# --- opus -----------------------------------------------------------------
build_opus() {
  [ -f "$PREFIX/lib/opus.lib" ] && { echo "== opus present"; return; }
  echo "== opus"
  local d=/tmp/opus
  git clone --depth 1 --branch v1.4 https://github.com/xiph/opus "$d"
  cmake -S "$d" -B "$d/build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DOPUS_BUILD_TESTING=OFF -DOPUS_BUILD_PROGRAMS=OFF
  cmake --build "$d/build" -j "$JOBS"
  cmake --install "$d/build"
}

# --- libvpx ---------------------------------------------------------------
build_libvpx() {
  [ -f "$PREFIX/lib/vpx.lib" ] && { echo "== libvpx present"; return; }
  echo "== libvpx"
  local d=/tmp/libvpx
  git clone --depth 1 --branch v1.14.1 https://chromium.googlesource.com/webm/libvpx "$d"
  cd "$d"
  # --target is the *host* triplet configure expects; the compiler below is
  # what actually decides the output platform.
  ./configure --target=x86_64-win64-gcc \
    --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    --enable-vp9 --enable-vp8
  make -j "$JOBS"
  make install
  cd -
}

# --- libaom ---------------------------------------------------------------
build_libaom() {
  [ -f "$PREFIX/lib/aom.lib" ] && { echo "== libaom present"; return; }
  echo "== libaom"
  local d=/tmp/libaom
  git clone --depth 1 --branch v3.9.1 https://aomedia.googlesource.com/aom "$d"
  cmake -S "$d" -B "$d/build" -G Ninja \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF \
    -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1
  cmake --build "$d/build" -j "$JOBS"
  cmake --install "$d/build"
}

build_libyuv
build_opus
build_libvpx
build_libaom

echo "== done; contents of $PREFIX/lib:"
ls -la "$PREFIX/lib" || true
