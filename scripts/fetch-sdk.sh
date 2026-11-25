#!/usr/bin/env sh
# Fetch (and optionally install) the SDK from the upstream GitHub release.
#
#   ./fetch-sdk.sh            download to ~/.config/dev-flutter/ and verify
#   ./fetch-sdk.sh --save     download straight into vendor/ (make the skill offline again)
#   ./fetch-sdk.sh --install  download, verify, apt install + post_install
#
# The skill normally ships the archive in vendor/; this script is the escape hatch for a
# fresh clone without the binary, or for deliberately moving to a newer tag.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

TAG=${FLUTTER_TAG:-3.50.1-1}
NAME="flutter_${TAG}_aarch64.deb"
# This skill's own release is tried first (the .deb is too big for git: GitHub caps files at
# 100 MB, so vendor/ holds only the checksums and the archive lives as a release asset).
MIRROR_BASE=${FLUTTER_MIRROR_BASE:-https://github.com/atfa/dev-flutter-on-android/releases/download/sdk-$TAG}
UPSTREAM_BASE=${FLUTTER_UPSTREAM_BASE:-https://github.com/GeneralKaos666/flutter-for-termux/releases/download/$TAG}

DEST="$STATE_DIR"
INSTALL=0
for a in "$@"; do
  case "$a" in
    --save) DEST="$VENDOR" ;;
    --install) INSTALL=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) die "unknown flag: $a" ;;
  esac
done
mkdir -p "$DEST"

step "Downloading $NAME (tag $TAG)"
GOT=
for base in "$MIRROR_BASE" "$UPSTREAM_BASE"; do
  say "  trying $base"
  if curl -fL --retry 2 --retry-delay 2 -o "$DEST/$NAME" "$base/$NAME"; then
    curl -fsSL --retry 2 -o "$DEST/$NAME.sha256" "$base/$NAME.sha256" || { warn "no checksum at $base - skipping"; continue; }
    curl -fsSL --retry 2 -o "$DEST/$NAME.size.txt" "$base/$NAME.size.txt" || true
    GOT=$base
    break
  fi
  rm -f "$DEST/$NAME"
done
[ -n "$GOT" ] || die "download failed from both the mirror and upstream"

step "Verifying"
(cd "$DEST" && sha256sum -c "$NAME.sha256") || die "sha256 mismatch - do not install"
if [ -s "$DEST/$NAME.size.txt" ]; then
  WANT=$(cat "$DEST/$NAME.size.txt")
  GOT=$(stat -c %s "$DEST/$NAME")
  [ "$WANT" = "$GOT" ] || die "size mismatch: got $GOT, expected $WANT"
  say "size ok ($GOT bytes)"
fi
sha256sum "$DEST/$NAME" >"$DEST/SHA256SUMS"
say "saved: $DEST/$NAME"

if [ "$INSTALL" = 1 ]; then
  step "Installing"
  DEBIAN_FRONTEND=noninteractive apt install -y "$DEST/$NAME" || die "apt install failed"
  step "post_install"
  bash "$FLUTTER_SHARE/post_install.sh" || warn "post_install reported a problem: $FLUTTER_SHARE/post_install.log"
  sh "$HERE/fix-tester.sh"
  "$FLUTTER_ROOT/bin/flutter" --version | head -1
fi
