#!/usr/bin/env sh
# Build the project in the current directory.
#
#   ./build.sh                 release APK (arm64, no tree-shaken icons)
#   ./build.sh debug           debug APK (JIT, for `flutter run`-style iteration)
#   ./build.sh aab             App Bundle
#   ./build.sh linux           Linux/GTK desktop bundle (run it under Termux:X11)
#
# Every APK is checked for AndroidManifest.xml + resources.arsc before it is reported as
# good: the R8/aapt2 combination can produce a package that builds and then fails to
# install (INSTALL_PARSE_FAILED) - the check catches that in seconds.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

WHAT=${1:-release}
[ $# -gt 0 ] && shift
EXTRA=$*

[ -f pubspec.yaml ] || die "no pubspec.yaml in $PWD - cd into the Flutter project"
project_configured "$PWD" || {
  warn "project not configured for Termux - running the configurator"
  configure_project "$PWD"
}

T0=$(date +%s)
step "flutter build ($WHAT)"
case "$WHAT" in
  release)
    "$FLUTTER_ROOT/bin/flutter" build apk --release \
      --target-platform android-arm64 --no-tree-shake-icons $EXTRA
    APK=build/app/outputs/flutter-apk/app-release.apk
    ;;
  debug)
    "$FLUTTER_ROOT/bin/flutter" build apk --debug --target-platform android-arm64 $EXTRA
    APK=build/app/outputs/flutter-apk/app-debug.apk
    ;;
  aab)
    "$FLUTTER_ROOT/bin/flutter" build appbundle --release \
      --target-platform android-arm64 --no-tree-shake-icons $EXTRA
    APK=build/app/outputs/bundle/release/app-release.aab
    ;;
  linux)
    "$FLUTTER_ROOT/bin/flutter" build linux --release $EXTRA
    DIR=build/linux/arm64/release/bundle
    BIN=$(awk -F': *' '/^name:/{print $2; exit}' pubspec.yaml)
    say "bundle: $DIR ($(du -sh "$DIR" 2>/dev/null | cut -f1))"
    say "run it under Termux:X11:  DISPLAY=:0 $DIR/$BIN"
    exit 0
    ;;
  *) die "unknown target: $WHAT (release|debug|aab|linux)" ;;
esac

T=$(elapsed "$T0")

[ -f "$APK" ] || die "build reported success but $APK is missing"
step "Verifying package structure"
LIST=$(unzip -l "$APK" 2>/dev/null || true)
printf '%s\n' "$LIST" | grep -q 'AndroidManifest.xml' ||
  die "$APK has no AndroidManifest.xml - this package will not install"
if [ "$WHAT" != aab ]; then
  printf '%s\n' "$LIST" | grep -q 'resources.arsc' ||
    die "$APK has no resources.arsc - resource shrinking removed it (see references/pitfalls.md)"
fi
say "AndroidManifest.xml + resources.arsc present"

SIZE=$(stat -c %s "$APK")
step "Done in $T"
say "$APK  $((SIZE / 1048576)) MB"
if [ "$SIZE" -gt 80000000 ] && [ "$WHAT" != aab ]; then
  warn "the bundled libflutter.so arrives unstripped from Maven (170 MB) because there is no NDK strip tool"
  say "shrink it 10x:  sh $HERE/slim-apk.sh $APK"
fi
