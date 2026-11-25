#!/usr/bin/env sh
# Shrink a release APK ~10x by stripping the engine library.
#
#   ./slim-apk.sh [apk] [out.apk]
#
# Why this exists: the Flutter engine arrives from Maven (io.flutter:arm64_v8a_release) as
# an *unstripped* libflutter.so (~170 MB). AGP normally strips native libraries with the
# NDK's strip tool; this SDK has no NDK, so the 170 MB file goes straight into the APK. The
# result installs and runs fine, but every install pushes 170 MB - strip it and the same
# APK is ~17 MB.
#
# Signing: debug keystore by default, so the package stays installable/upgradable.
#   DEV_FLUTTER_KS, DEV_FLUTTER_KS_PASS, DEV_FLUTTER_KS_ALIAS override it.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

IN=${1:-build/app/outputs/flutter-apk/app-release.apk}
[ -f "$IN" ] || die "no apk: $IN"
case "$IN" in /*) ;; *) IN="$PWD/$IN" ;; esac
OUT=${2:-${IN%.apk}-slim.apk}

for t in llvm-strip zipalign apksigner zip unzip; do
  have "$t" || die "missing $t (pkg install clang android-tools zip apksigner)"
done

WORK=$TMPDIR/dev-flutter-slim
rm -rf "$WORK"; mkdir -p "$WORK"

step "Stripping native libraries"
(cd "$WORK" && unzip -q "$IN" 'lib/*/*.so' 2>/dev/null || true)
FOUND=0
SAVED=0
for so in "$WORK"/lib/*/*.so; do
  [ -f "$so" ] || continue
  FOUND=$((FOUND + 1))
  before=$(stat -c %s "$so")
  llvm-strip --strip-unneeded "$so"
  after=$(stat -c %s "$so")
  SAVED=$((SAVED + before - after))
  say "  ${so#$WORK/}  $((before / 1048576)) MB -> $((after / 1048576)) MB"
done
[ "$FOUND" -gt 0 ] || die "no lib/*/*.so inside $IN - is this a Flutter APK?"
[ "$SAVED" -gt 0 ] || { say "nothing to strip (already slim)"; exit 0; }

step "Repacking (stored, page aligned)"
cp "$IN" "$WORK/base.apk"
(cd "$WORK" && zip -0 -q base.apk lib/*/*.so)
zipalign -f -p 4 "$WORK/base.apk" "$WORK/aligned.apk"

step "Signing"
KS=${DEV_FLUTTER_KS:-$HOME/.android/debug.keystore}
KP=${DEV_FLUTTER_KS_PASS:-android}
KA=${DEV_FLUTTER_KS_ALIAS:-androiddebugkey}
[ -f "$KS" ] || die "no keystore at $KS (build once with flutter, or set DEV_FLUTTER_KS)"
cp "$WORK/aligned.apk" "$OUT"
apksigner sign --ks "$KS" --ks-pass "pass:$KP" --key-pass "pass:$KP" --ks-key-alias "$KA" "$OUT"
apksigner verify "$OUT" >/dev/null || die "signature verify failed"

step "Done"
say "$OUT"
say "  $(($(stat -c %s "$IN") / 1048576)) MB -> $(($(stat -c %s "$OUT") / 1048576)) MB"
say "install: sh $HERE/install.sh $OUT"
