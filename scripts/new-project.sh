#!/usr/bin/env sh
# Create a Flutter project that builds on this phone.
#
#   ./new-project.sh ~/apps/hello [--org com.example] [--no-linux] [--offline] [--heap 3G]
#
# Does: flutter create -> upstream configurator (aapt2 override, compileSdk 36, arm64 only)
#       -> cap Gradle heap -> verify the gradlew shebang.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

DIR=
ORG=com.example
PLATFORMS=android,linux
OFFLINE=
HEAP=3G
while [ $# -gt 0 ]; do
  case "$1" in
    --org) ORG=$2; shift 2 ;;
    --no-linux) PLATFORMS=android; shift ;;
    --offline) OFFLINE=--offline; shift ;;
    --heap) HEAP=$2; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) DIR=$1; shift ;;
  esac
done
[ -n "$DIR" ] || die "usage: new-project.sh <dir> [--org com.example]"
case "$DIR" in /*) ;; *) DIR="$PWD/$DIR" ;; esac
[ -e "$DIR" ] && die "$DIR already exists"

flutter_ok || die "flutter is not installed - run scripts/setup.sh"

NAME=$(basename "$DIR" | tr -cs 'a-zA-Z0-9_' '_')
step "flutter create $DIR ($PLATFORMS, org $ORG)"
# --offline only works once ~/.pub-cache is warm; the first project on a device needs pub.dev.
"$FLUTTER_ROOT/bin/flutter" create --platforms="$PLATFORMS" --org "$ORG" \
  --project-name "${NAME%_}" $OFFLINE "$DIR" >/dev/null ||
  die "flutter create failed"

cd "$DIR"
step "Configuring for Termux (upstream flutter_project_config.sh)"
configure_project "$DIR"

cap_gradle_heap "$DIR" "$HEAP"
say "org.gradle.jvmargs capped at -Xmx$HEAP (the template ships 8G)"

if [ -f android/gradlew ]; then
  head -1 android/gradlew | grep -q "^#!/data/data/" ||
    sed -i "1s|.*|#!/data/data/com.termux/files/usr/bin/bash|" android/gradlew
  chmod 755 android/gradlew
fi

project_configured "$DIR" || die "project still lacks aapt2FromMavenOverride - check the configurator output"
grep -q 'abiFilters += listOf("arm64-v8a")' android/app/build.gradle.kts 2>/dev/null ||
  warn "no arm64 abiFilters found - the APK may contain other ABIs"

step "Ready"
say "  cd $DIR"
say "  sh $HERE/build.sh release      # APK (first build downloads Gradle, 10-20 min)"
say "  sh $HERE/run.sh                # hot reload on this device (needs adb)"
say "  sh $HERE/run.sh --linux        # hot reload in Termux:X11 instead"
