#!/usr/bin/env sh
# Iterate on the project in the current directory.
#
#   ./run.sh                 hot reload on this phone (attaches adb, then `flutter run`)
#   ./run.sh --release       same, in release mode (no hot reload, real performance)
#   ./run.sh --linux         hot reload in the Linux/GTK window (needs Termux:X11)
#   ./run.sh --test          `flutter test` (pure-Dart tests only - see references/limits.md)
#   ./run.sh -- <args>       everything after -- goes to `flutter`
#
# Hot reload keys: r = reload, R = restart, p = performance overlay, q = quit.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

TARGET=android
MODE=
SERIAL=
while [ $# -gt 0 ]; do
  case "$1" in
    --linux) TARGET=linux; shift ;;
    --test) TARGET=test; shift ;;
    --release) MODE=--release; shift ;;
    --profile) MODE=--profile; shift ;;
    --serial) SERIAL=$2; shift 2 ;;
    --) shift; break ;;
    -*) die "unknown flag: $1" ;;
    *) break ;;
  esac
done
EXTRA=$*

[ -f pubspec.yaml ] || die "no pubspec.yaml in $PWD - cd into the Flutter project"
flutter_ok || die "flutter is not installed - run scripts/setup.sh"

case "$TARGET" in
  test)
    if [ ! -f "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/libvk_swiftshader.so" ]; then
      warn "flutter_tester cannot start yet - installing the shim"
      sh "$HERE/fix-tester.sh"
    fi
    step "flutter test"
    exec "$FLUTTER_ROOT/bin/flutter" test $EXTRA
    ;;

  linux)
    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
      warn "no DISPLAY set. Start Termux:X11 first:"
      say "  termux-x11 :0 >/dev/null 2>&1 &"
      say "  export DISPLAY=:0"
      die "no display"
    fi
    step "flutter run -d linux (DISPLAY=$DISPLAY)"
    exec "$FLUTTER_ROOT/bin/flutter" run -d linux $MODE $EXTRA
    ;;

  android)
    if [ -z "$SERIAL" ]; then
      SERIAL=$(adb_serial || true)
    fi
    if [ -z "$SERIAL" ]; then
      warn "no device attached to adb"
      if su -c true >/dev/null 2>&1; then
        say "root available - enabling tcp adbd on 127.0.0.1:5555"
        sh "$HERE/adb-ondevice.sh" start || die "could not attach adb"
        SERIAL=$(adb_serial)
      else
        say "no root: enable Developer options -> Wireless debugging, then:"
        say "  adb pair 127.0.0.1:<pairing-port>"
        say "  adb connect 127.0.0.1:<debug-port>"
        die "no adb device"
      fi
    fi
    step "flutter run -d $SERIAL $MODE"
    say "first build takes minutes (Gradle); afterwards r/R are instant"
    exec "$FLUTTER_ROOT/bin/flutter" run -d "$SERIAL" $MODE $EXTRA
    ;;
esac
