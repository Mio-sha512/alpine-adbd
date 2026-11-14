#!/bin/sh
# build-local.sh -- fetch the pinned nmeum/android-tools release tarball,
# apply this repo's patch series, and build a standalone static adbd.
#
# Run inside an environment with cmake + ninja + a compiler. To
# cross-compile, point CMAKE_TOOLCHAIN_FILE at a toolchain file:
#
#   CMAKE_TOOLCHAIN_FILE=$PWD/cmake/toolchains/aarch64-linux-gnu.cmake \
#       ./scripts/build-local.sh
#
# Env: ANDROID_TOOLS_TAG (default: _upstream from adbd/APKBUILD),
#      WORK (build scratch dir), JOBS.
#
# Every downloaded distfile is verified against the sha512sums in
# adbd/APKBUILD before extraction -- the same sums abuild enforces,
# so both build paths compile identical, checksum-anchored bytes.
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
PKG_DIR="$REPO/adbd"
TAG="${ANDROID_TOOLS_TAG:-$(sed -n 's/^_upstream=//p' "$PKG_DIR/APKBUILD" | tr -d '"'"'"' \t')}"
WORK="${WORK:-$REPO/work}"
SRC="$WORK/android-tools-$TAG"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

for c in curl tar xz patch cmake ninja sha512sum; do
	command -v "$c" >/dev/null 2>&1 || { echo "missing dependency: $c" >&2; exit 1; }
done

mkdir -p "$WORK"

# Extract the checksum block from the APKBUILD (hash<2 spaces>filename lines).
sed -n '/^sha512sums="/,/^"/p' "$PKG_DIR/APKBUILD" \
	| sed '1s/.*="//; $s/"$//; s/^ *//' > "$WORK/.sums"

# verify <filename>: true iff $WORK/<filename> exists AND has a sum entry
# AND matches it. Explicit about the entry: an absent entry must fail, not
# rely on sha512sum -c rejecting empty stdin.
verify() {
	grep -q "  $1\$" "$WORK/.sums" || return 1
	grep "  $1\$" "$WORK/.sums" | (cd "$WORK" && sha512sum -c -) >/dev/null 2>&1
}

# fetch <url> <distfile-name>: download to a temp name, verify, rename.
# A cached file that verifies is kept; anything else is refetched.
fetch() {
	verify "$2" && return 0
	rm -f "$WORK/$2" "$WORK/$2.part"
	curl -fSL --retry 3 --connect-timeout 15 -o "$WORK/$2.part" "$1"
	mv "$WORK/$2.part" "$WORK/$2"
	verify "$2" || { echo "checksum mismatch: $2" >&2; exit 1; }
}

fetch "https://github.com/nmeum/android-tools/releases/download/$TAG/android-tools-$TAG.tar.xz" \
	"android-tools-$TAG.tar.xz"

rm -rf "$SRC"
tar -xJf "$WORK/android-tools-$TAG.tar.xz" -C "$WORK"

# The release tarball does not carry third_party compression libs; fetch the
# pins recorded in adbd/APKBUILD (_*_sha) for a static link.
_brotli_sha=$(sed -n 's/^_brotli_sha=//p' "$PKG_DIR/APKBUILD")
_lz4_sha=$(sed -n 's/^_lz4_sha=//p' "$PKG_DIR/APKBUILD")
_zstd_sha=$(sed -n 's/^_zstd_sha=//p' "$PKG_DIR/APKBUILD")
THIRD_PARTY="brotli $_brotli_sha google
lz4 $_lz4_sha lz4
zstd $_zstd_sha facebook"
echo "$THIRD_PARTY" | while read -r name sha org; do
	fetch "https://github.com/$org/$name/archive/$sha.tar.gz" "$sha.tar.gz"
	mkdir -p "$SRC/vendor/third_party/$name"
	tar -xzf "$WORK/$sha.tar.gz" -C "$SRC/vendor/third_party/$name" --strip-components=1
done

cd "$SRC"
cp "$PKG_DIR/vendor-CMakeLists.txt" vendor/CMakeLists.txt
for p in "$PKG_DIR"/00*.patch; do
	patch -f -p1 -d vendor/adb < "$p"
done
cp "$PKG_DIR/CMakeLists.adbd-daemon.txt" vendor/
mkdir -p vendor/linux-adbd/include/sys vendor/linux-adbd/include/google/protobuf/io
cp "$PKG_DIR/adbd-stubs.cpp" vendor/linux-adbd/stubs.cpp
cp "$PKG_DIR/sys-capability.h" vendor/linux-adbd/include/sys/capability.h
# satisfy sysdeps.h's __has_include protobuf probes without dragging in absl
cp "$PKG_DIR/protobuf-descriptor.h" vendor/linux-adbd/include/google/protobuf/descriptor.h
cp "$PKG_DIR/protobuf-coded-stream.h" vendor/linux-adbd/include/google/protobuf/io/coded_stream.h

cmake -B "$WORK/build-$TAG" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DANDROID_TOOLS_PATCH_VENDOR=OFF \
	-DANDROID_TOOLS_USE_BUNDLED_FMT=ON \
	-DANDROID_TOOLS_BUILD_ADBD_ONLY=ON \
	-DANDROID_TOOLS_ADBD_FULLY_STATIC=ON \
	-DANDROID_TOOLS_ADBD_USB=ON \
	${CMAKE_TOOLCHAIN_FILE:+-DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE"}
cmake --build "$WORK/build-$TAG" --target adbd -j "$JOBS"

echo "built: $WORK/build-$TAG/vendor/adbd"
