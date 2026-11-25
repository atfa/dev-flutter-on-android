#!/usr/bin/env sh
# Install / verify the on-device Flutter SDK.
#
#   ./setup.sh                 use vendor/flutter_*.deb (offline, default)
#   ./setup.sh --fetch         download the .deb from the upstream release instead
#   ./setup.sh --fix-aapt2     repoint apt at the maintained Termux mirror and upgrade the
#                              aapt2 stack (needed when the installed aapt2 cannot read
#                              platforms/android-36/android.jar - see references/pitfalls.md)
#   ./setup.sh --ndk           additionally provision the aarch64 NDK (~550 MB, only needed
#                              for plugins with native code)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

MODE=vendor
FIX_AAPT2=0
NDK=0
for a in "$@"; do
  case "$a" in
    --fetch) MODE=fetch ;;
    --fix-aapt2) FIX_AAPT2=1 ;;
    --ndk) NDK=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "unknown flag: $a" ;;
  esac
done

[ "$(uname -m)" = aarch64 ] || die "this SDK is aarch64 only (uname -m = $(uname -m))"

# ---------------------------------------------------------------- 1. Termux packages
step "Termux packages"
pkg install -y x11-repo >/dev/null 2>&1 || warn "x11-repo install failed - gtk3/ninja/cmake may be missing"
pkg install -y gnupg openjdk-21 aapt2 apksigner android-tools zip unzip which git \
  cmake ninja pkg-config clang >/dev/null 2>&1 || die "pkg install failed"
say "openjdk-21 $(pkg_version openjdk-21)"

# ---------------------------------------------------------------- 2. aapt2 sanity
# aapt2 must be able to link against platforms/android-36/android.jar. The old
# 13.0.0.6 build (still served by the stale termux.net mirror) fails with
#   AAPT: error: failed to load include path .../android-36/android.jar
AAPT2_VER=$(pkg_version aapt2)
if version_ge "$AAPT2_VER" 16.0.0.0; then
  say "aapt2 $AAPT2_VER (ok)"
else
  warn "aapt2 $AAPT2_VER is too old for compileSdk 36 (needs >= 16.0.0.4)"
  if [ "$FIX_AAPT2" = 1 ]; then
    step "Repointing apt at packages-cf.termux.dev and upgrading the aapt2 stack"
    SRC=$PREFIX/etc/apt/sources.list.d/termux.sources
    [ -f "$SRC.bak" ] || cp "$SRC" "$SRC.bak"
    sed -i 's|^URIs: https://termux\.net$|URIs: https://packages-cf.termux.dev/apt/termux-main|' "$SRC"
    sed -i '/^Signed-By:/d' "$SRC"   # let trusted.gpg.d hold both the old and the new key
    if [ ! -f "$PREFIX/etc/apt/trusted.gpg.d/termux-main-modern.gpg" ]; then
      curl -fsSL -m 60 "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x5A897D96E57CF20C" \
        -o "$STATE_DIR/termux-main.asc" || die "could not fetch the Termux release key"
      gpg --show-keys --with-fingerprint "$STATE_DIR/termux-main.asc" 2>/dev/null |
        grep -q '5A89 7D96 E57C F20C' || die "fetched key is not the Termux release key - refusing"
      gpg --dearmor <"$STATE_DIR/termux-main.asc" >"$PREFIX/etc/apt/trusted.gpg.d/termux-main-modern.gpg"
      chmod 644 "$PREFIX/etc/apt/trusted.gpg.d/termux-main-modern.gpg"
    fi
    pkg update >/dev/null 2>&1 || die "apt update failed - check $SRC"
    # These five must move together: aapt2 links the new fmt/protobuf/abseil ABI.
    apt-get install -y aapt2 libprotobuf abseil-cpp libc++ fmt libexpat libpng zlib libzopfli ||
      die "aapt2 upgrade failed"
    AAPT2_VER=$(pkg_version aapt2)
    "$PREFIX/bin/aapt2" version >/dev/null 2>&1 ||
      die "aapt2 still cannot start - run: apt-get install -y aapt2 libprotobuf abseil-cpp libc++ fmt"
    say "aapt2 upgraded to $AAPT2_VER"
  else
    warn "re-run with --fix-aapt2, or pin compileSdk 35 as a stopgap (references/pitfalls.md)"
  fi
fi
say "aapt2 reports: $("$PREFIX/bin/aapt2" version 2>&1 | head -1)"

# ---------------------------------------------------------------- 3. the SDK itself
if flutter_ok; then
  say "flutter already installed: $("$FLUTTER_ROOT/bin/flutter" --version 2>/dev/null | head -1)"
else
  step "Installing $DEB_NAME"
  if [ "$MODE" = fetch ]; then
    sh "$HERE/fetch-sdk.sh" --install
  else
    DEB="$VENDOR/$DEB_NAME"
    [ -f "$DEB" ] || die "missing $DEB - run: sh scripts/fetch-sdk.sh --save  (or setup.sh --fetch)"
    EXPECT=$(awk '{print $1}' "$VENDOR/SHA256SUMS")
    step "Verifying the vendored archive"
    GOT=$(sha256sum "$DEB" | awk '{print $1}')
    [ "$GOT" = "$EXPECT" ] || die "sha256 mismatch: got $GOT, expected $EXPECT"
    say "sha256 ${GOT%??????}… ok ($(stat -c %s "$DEB") bytes)"
    DEBIAN_FRONTEND=noninteractive apt install -y "$DEB" || die "apt install failed"
  fi
  step "post_install (idempotent; repairs engine stamps, SDK, Gradle plugin cache)"
  if [ "$NDK" = 1 ]; then
    bash "$FLUTTER_SHARE/post_install.sh" --provision-ndk
  else
    bash "$FLUTTER_SHARE/post_install.sh"
  fi || die "post_install failed - see $FLUTTER_SHARE/post_install.log"
fi

# ---------------------------------------------------------------- 4. licences + tester stub
step "Android SDK licences"
yes 2>/dev/null | "$FLUTTER_ROOT/bin/flutter" doctor --android-licenses >/dev/null 2>&1 || true
say "accepted"

step "flutter_tester shim (the .deb omits libvk_swiftshader.so, so \`flutter test\` cannot exec)"
sh "$HERE/fix-tester.sh"

# ---------------------------------------------------------------- 5. verify
step "Verify"
"$FLUTTER_ROOT/bin/flutter" --version | sed -n '1p;4p'
"$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" --version 2>&1 | head -1
say "sdk $FLUTTER_ROOT    android-sdk $ANDROID_SDK_ROOT"

cat >"$STATE_DIR/installed.env" <<EOF
FLUTTER_VERSION=$("$FLUTTER_ROOT/bin/flutter" --version 2>/dev/null | head -1 | awk '{print $2}')
FLUTTER_ROOT=$FLUTTER_ROOT
ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT
JAVA_HOME=$JAVA_HOME
AAPT2_VERSION=$AAPT2_VER
DEB_SHA256=$(sha256sum "$VENDOR/$DEB_NAME" 2>/dev/null | awk '{print $1}')
EOF
say "state: $STATE_DIR/installed.env"
say "next: sh $HERE/new-project.sh \$HOME/apps/hello"
