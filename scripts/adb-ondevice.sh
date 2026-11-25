#!/usr/bin/env sh
# Point Termux's adb at this phone's own adbd, so `flutter run` can hot-reload.
#
#   ./adb-ondevice.sh start [port]    root: enable tcp adbd + adb connect 127.0.0.1:port
#   ./adb-ondevice.sh stop            disconnect and put adbd back on USB only
#   ./adb-ondevice.sh status
#
# Without root there is no scriptable route: enable developer options -> Wireless debugging
# -> "Pair device with pairing code", then `adb pair 127.0.0.1:<port>` once. See
# references/run.md.
#
# SECURITY: an open 5555 listens on every interface. `stop` is not optional.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib/common.sh"
. "$HERE/../lib/flutter.sh"

PORT=${2:-5555}
CMD=${1:-status}

asroot() { su -c "$1"; }
have_root() { su -c true >/dev/null 2>&1; }

case "$CMD" in
  start)
    have_root || die "no root: use Wireless debugging + 'adb pair 127.0.0.1:<port>' instead"
    step "Enabling tcp adbd on port $PORT"
    asroot "setprop service.adb.tcp.port $PORT; stop adbd; start adbd" || die "could not restart adbd"
    i=0
    while [ $i -lt 20 ]; do
      [ "$(getprop service.adb.tcp.port)" = "$PORT" ] && break
      sleep 0.5; i=$((i + 1))
    done
    adb start-server >/dev/null 2>&1 || true
    step "Connecting"
    adb connect "127.0.0.1:$PORT" || die "adb connect failed"
    sleep 1
    S=$(adb_serial | grep "127.0.0.1:$PORT" || true)
    [ -n "$S" ] || die "adbd did not answer on 127.0.0.1:$PORT (check 'adb devices')"
    say "connected: $S"
    say "flutter run -d $S"
    ;;
  stop)
    adb disconnect "$(adb_serial)" >/dev/null 2>&1 || true
    if have_root; then
      asroot "setprop service.adb.tcp.port -1; stop adbd; start adbd" >/dev/null 2>&1 || true
      say "adbd back on USB; tcp port closed"
    else
      say "no root: turn Wireless debugging off in developer options"
    fi
    ;;
  status)
    say "service.adb.tcp.port = $(getprop service.adb.tcp.port)"
    say "root: $(have_root && echo yes || echo no)"
    adb devices 2>/dev/null | sed 's/^/  /'
    ;;
  *) die "usage: adb-ondevice.sh start|stop|status [port]" ;;
esac
