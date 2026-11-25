#!/usr/bin/env sh
# Install an APK on this device.
#
#   ./install.sh [apk] [--bg]
#     root  : silent `pm install -r -g` + launch
#     no root: termux-open, one tap in the system installer
#     --bg  : launch on the invisible virtual display instead of the main screen
#             (root only; the richer driver - tap/swipe/shot - lives in dev-apk-on-android)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

BG=0
APK=
for a in "$@"; do
  case "$a" in
    --bg) BG=1 ;;
    *) APK=$a ;;
  esac
done
APK=$(readlink -f "${APK:-build/app/outputs/flutter-apk/app-release.apk}")
[ -f "$APK" ] || die "no apk: $APK (run scripts/build.sh first)"

PACKAGE=$(unzip -p "$APK" AndroidManifest.xml >/dev/null 2>&1 && "$PREFIX/bin/aapt2" dump packagename "$APK" 2>/dev/null || true)
[ -n "$PACKAGE" ] || PACKAGE=unknown

if ! su -c true >/dev/null 2>&1; then
  say "no root: opening the system installer - tap Install"
  termux-open "$APK"
  say "package: $PACKAGE"
  exit 0
fi

STAGE=/data/local/tmp/$(basename "$APK")
su -c "cp '$APK' '$STAGE' && chmod 644 '$STAGE'" || die "staging failed"
step "pm install -r -g (root)"
su -c "pm install -r -g '$STAGE'" || die "install failed - check 'logcat' for INSTALL_* errors"

if [ "$BG" = 1 ]; then
  DRIVER=$(dirname "$HERE")/../dev-apk-on-android/scripts/vd.sh
  if [ -x "$DRIVER" ]; then
    sh "$DRIVER" create >/dev/null 2>&1 || true
    sh "$DRIVER" launch
    say "running on the background display - screenshot: sh $DRIVER shot"
  else
    warn "--bg needs the dev-apk-on-android skill (scripts/vd.sh)"
  fi
else
  step "Launching"
  su -c "am start -W -n $PACKAGE/.MainActivity" 2>&1 | grep -E 'Status|TotalTime|Error' || warn "could not launch - check 'logcat'"
fi
