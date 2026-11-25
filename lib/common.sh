#!/usr/bin/env sh
# Shared helpers for every script in this skill. POSIX sh only.
set -eu

SKILL_DIR=$(cd "$(dirname "$0")/.." && pwd)
VENDOR="$SKILL_DIR/vendor"
DEB_NAME=flutter_3.50.1-1_aarch64.deb

# Where logs and the installed-state file live (not inside the skill, not in $TMPDIR).
STATE_DIR=${DEV_FLUTTER_STATE:-$HOME/.config/dev-flutter}
mkdir -p "$STATE_DIR" 2>/dev/null || true

say()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# version of an installed Termux package, empty when missing
pkg_version() { dpkg-query -W -f '${Version}' "$1" 2>/dev/null || true; }

# True when $1 >= $2 for dotted numeric versions (13.0.0.6-23 style suffixes are ignored).
version_ge() {
  awk -v a="${1%%-*}" -v b="${2%%-*}" 'BEGIN{
    n = split(a, x, "."); m = split(b, y, ".")
    k = (n > m ? n : m)
    for (i = 1; i <= k; i++) {
      p = x[i] + 0; q = y[i] + 0
      if (p > q) exit 0
      if (p < q) exit 1
    }
    exit 0
  }'
}

elapsed() { # elapsed <start-epoch>
  now=$(date +%s)
  s=$((now - $1))
  printf '%dm%02ds' $((s / 60)) $((s % 60))
}
