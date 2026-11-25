#!/usr/bin/env sh
# One screen of facts about this phone as a Flutter build host.
#
#   ./doctor.sh
#
# Run this first when something "worked yesterday": it distinguishes a broken SDK from a
# broken package (aapt2), a stale mirror, a full disk, and a missing adb device.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
# not lib/flutter.sh: doctor must work even when no JDK/SDK is installed yet
FLUTTER_ROOT=${FLUTTER_ROOT:-$PREFIX/opt/flutter}

row() { printf '  %-22s %s\n' "$1" "$2"; }

say "device"
row "arch" "$(uname -m)$([ "$(uname -m)" = aarch64 ] || echo '  <-- unsupported, this SDK is arm64 only')"
row "android" "$(getprop ro.build.version.release) (sdk $(getprop ro.build.version.sdk))"
row "page size" "$(getconf PAGE_SIZE) bytes"
row "root" "$(su -c id 2>/dev/null | sed -n 's/.*uid=0(root).*/yes/p' || true)"
row "storage free" "$(df -h /data | awk 'NR==2{print $4}')"
row "memory" "$(awk '/MemTotal/{printf "%d MB", $2/1024}' /proc/meminfo)"

say "toolchain"
row "java" "$(ls -d "$PREFIX/lib/jvm/"java-*-openjdk 2>/dev/null | tail -1 | xargs -r basename)"
row "aapt2 package" "$(pkg_version aapt2)"
row "aapt2 runs" "$("$PREFIX/bin/aapt2" version 2>&1 | head -1)"
if version_ge "$(pkg_version aapt2)" 16.0.0.0; then
  row "aapt2 verdict" "ok for compileSdk 36"
else
  row "aapt2 verdict" "TOO OLD for android-36 -> scripts/setup.sh --fix-aapt2"
fi
row "apksigner" "$(pkg_version apksigner)"
row "zipalign" "$(command -v zipalign >/dev/null 2>&1 && echo present || echo missing)"
row "clang" "$(clang --version 2>/dev/null | head -1 | awk '{print $3}')"
row "termux mirror" "$(sed -n 's/^URIs: //p' "$PREFIX/etc/apt/sources.list.d/termux.sources" 2>/dev/null)"

say "sdk"
row "flutter" "$( [ -x "$FLUTTER_ROOT/bin/flutter" ] && "$FLUTTER_ROOT/bin/flutter" --version 2>/dev/null | head -1 || echo missing)"
row "flutter root" "$([ -d "$FLUTTER_ROOT" ] && du -sh "$FLUTTER_ROOT" 2>/dev/null | cut -f1 || echo missing)"
row "android sdk" "$( [ -d "$PREFIX/opt/android-sdk" ] && du -sh "$PREFIX/opt/android-sdk" | cut -f1 || echo missing)"
row "platforms" "$(ls "$PREFIX/opt/android-sdk/platforms" 2>/dev/null | tr '\n' ' ')"
row "build-tools" "$(ls "$PREFIX/opt/android-sdk/build-tools" 2>/dev/null | tr '\n' ' ')"
row "ndk" "$(ls "$PREFIX/opt/android-sdk/ndk" 2>/dev/null | tr '\n' ' ')"
row "flutter_tester" "$([ -f "$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-arm64/libvk_swiftshader.so" ] && echo 'runnable (shim)' || echo 'MISSING shim -> scripts/fix-tester.sh')"
row "gradle cache" "$(du -sh "${GRADLE_USER_HOME:-$HOME/.gradle}" 2>/dev/null | cut -f1)"
row "state" "$([ -f "$STATE_DIR/installed.env" ] && echo "$STATE_DIR/installed.env" || echo 'not installed by this skill')"

say "adb"
row "tcp port" "$(getprop service.adb.tcp.port)"
row "devices" "$(adb devices 2>/dev/null | awk 'NR>1 && NF{printf "%s ", $1}')"

say "termux:x11"
row "display" "${DISPLAY:-unset}"
row "x11 app" "$(pm list packages 2>/dev/null | grep -c com.termux.x11 || true)"
