#!/usr/bin/env sh
# Flutter-on-Termux environment. Source AFTER lib/common.sh.
#
# Everything here is derived from what the .deb installs - nothing is hardcoded to one
# Termux layout beyond the paths the package itself creates.

FLUTTER_ROOT=${FLUTTER_ROOT:-$PREFIX/opt/flutter}
ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-$PREFIX/opt/android-sdk}
ANDROID_HOME=$ANDROID_SDK_ROOT
TMPDIR=${TMPDIR:-$PREFIX/tmp}

# The deb ships exactly one JDK (openjdk-21); pick it, tolerate a future bump.
if [ -z "${JAVA_HOME:-}" ]; then
  for d in "$PREFIX/lib/jvm/java-21-openjdk" "$PREFIX/lib/jvm/java-"*-openjdk; do
    [ -x "$d/bin/java" ] && { JAVA_HOME=$d; break; }
  done
fi
[ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ] || {
  printf 'error: no JDK found under %s/lib/jvm - pkg install openjdk-21\n' "$PREFIX" >&2
  exit 1
}
export JAVA_HOME

# Gradle/AGP write here; keep them off /sdcard and out of $HOME/dotfiles.
GRADLE_USER_HOME=${GRADLE_USER_HOME:-$HOME/.gradle}

PATH="$FLUTTER_ROOT/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
export FLUTTER_ROOT ANDROID_SDK_ROOT ANDROID_HOME TMPDIR GRADLE_USER_HOME PATH

# Where the installed SDK's own maintenance scripts live (GPL-3 upstream code: call, never copy).
FLUTTER_SHARE=${FLUTTER_SHARE:-$PREFIX/share/flutter}

flutter_bin() { printf '%s/bin/flutter' "$FLUTTER_ROOT"; }

flutter_ok() {
  [ -x "$FLUTTER_ROOT/bin/flutter" ] && "$FLUTTER_ROOT/bin/flutter" --version >/dev/null 2>&1
}

# The five flags every on-device build needs. Written by the upstream configurator, so this
# is a read-only check - the skill never edits a project behind the configurator's back.
project_configured() { # project_configured <dir>
  p=$1/android/gradle.properties
  [ -f "$p" ] && grep -q '^android\.aapt2FromMavenOverride=' "$p"
}

configure_project() { # configure_project <dir>
  [ -f "$FLUTTER_SHARE/flutter_project_config.sh" ] ||
    { printf 'error: %s missing - rerun scripts/setup.sh\n' "$FLUTTER_SHARE/flutter_project_config.sh" >&2; return 1; }
  bash "$FLUTTER_SHARE/flutter_project_config.sh" "$1"
}

# The Flutter template ships -Xmx8G, which is a desktop default; a phone kills the daemon.
cap_gradle_heap() { # cap_gradle_heap <dir> [heap]
  p=$1/android/gradle.properties
  heap=${2:-3G}
  [ -f "$p" ] || return 0
  grep -q '^org\.gradle\.jvmargs=' "$p" || return 0
  sed -i "s|^org\.gradle\.jvmargs=.*|org.gradle.jvmargs=-Xmx$heap -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -Dfile.encoding=UTF-8|" "$p"
}

adb_serial() { # the one attached device, if any
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'
}
