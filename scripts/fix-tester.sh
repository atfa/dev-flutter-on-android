#!/usr/bin/env sh
# Make `flutter test` runnable on Termux.
#
# flutter_tester has DT_NEEDED libvk_swiftshader.so but the .deb does not ship the library,
# so every test run dies before Dart starts:
#   CANNOT LINK EXECUTABLE ".../flutter_tester": library "libvk_swiftshader.so" not found
#
# flutter_tester's RUNPATH is $PREFIX/lib only, so a stub there is found without touching
# the SDK or the environment. It exports the single symbol the binary needs
# (vkGetInstanceProcAddr); pure-Dart tests then run normally, widget tests still crash with
# SIGSEGV - see references/limits.md.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

ENGINE="$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64"
[ -x "$ENGINE/flutter_tester" ] || die "flutter_tester missing under $ENGINE - run scripts/setup.sh"

TARGET="$PREFIX/lib/libvk_swiftshader.so"
if [ -e "$TARGET" ] && [ "$(stat -c %s "$TARGET")" -gt 100000 ]; then
  say "a real libvk_swiftshader.so is already installed ($(stat -c %s "$TARGET") bytes) - nothing to do"
  exit 0
fi

SRC="$VENDOR/vkstub/libvk_swiftshader.c"
OUT="$STATE_DIR/libvk_swiftshader.so"
[ -f "$SRC" ] || die "missing $SRC"
command -v clang >/dev/null 2>&1 || die "clang not installed: pkg install clang"

if [ ! -f "$OUT" ] || [ "$SRC" -nt "$OUT" ]; then
  clang -shared -fPIC -O2 -o "$OUT" "$SRC" || die "stub build failed"
fi
cp "$OUT" "$TARGET"
say "installed shim: $TARGET"

if "$ENGINE/flutter_tester" --help >/dev/null 2>&1; then
  say "flutter_tester starts"
else
  die "flutter_tester still does not start - show: readelf -d $ENGINE/flutter_tester | grep RUNPATH"
fi
say "pure-Dart tests: cd <project> && sh scripts/run.sh --test"
say "the shim lives outside the SDK, so flutter/precache updates do not remove it"
