# Running and iterating

## Which loop to use

| you want | command | first time |
|---|---|---|
| check logic, no UI | `sh scripts/run.sh --test` | instant |
| see and touch the UI, real Android | `sh scripts/run.sh` | minutes (Gradle) |
| see the UI without giving up the phone | `sh scripts/run.sh --linux` under Termux:X11 | ~1 min |
| prove it as a package | `build.sh release` -> `slim-apk.sh` -> `install.sh` | ~1 min warm |

`flutter run` keys: `r` hot reload, `R` hot restart, `p` performance overlay, `q` quit.

## Attaching adb (needed for `flutter run`)

Termux's `adb` must talk to **this phone's** adbd. Three routes:

### 1. Root: TCP adbd on loopback (automatic, verified)

```sh
sh scripts/adb-ondevice.sh start          # setprop service.adb.tcp.port 5555; stop/start adbd; adb connect 127.0.0.1:5555
flutter devices                           # 127.0.0.1:5555  device
sh scripts/adb-ondevice.sh stop           # ALWAYS close it when done
```

`run.sh` does this for you when it finds no device and `su` works. `~/.android/adbkey` is
already authorised, so no tap is needed.

**Security:** an open 5555 accepts connections from every interface on the phone's
networks. `stop` resets `service.adb.tcp.port` to -1 and restarts adbd on USB only.

### 2. No root: wireless debugging with a pairing code

On the phone: Settings -> Developer options -> Wireless debugging -> *Pair device with
pairing code*. Then, in Termux:

```sh
adb pair 127.0.0.1:<pair_port>       # code shown on screen
adb connect 127.0.0.1:<debug_port>   # from the Wireless debugging screen
```

Both ports are random and change; the pairing has to be done by a human at least once.

### 3. USB to a PC

`adb tcpip 5555` from the PC, then `adb connect <phone-ip>:5555` from Termux - only useful
for debugging the setup, contradicts the no-PC premise.

## `flutter run` details

```sh
sh scripts/run.sh                      # debug, hot reload, picks the attached device
sh scripts/run.sh --release            # release on device (no hot reload; use for perf)
sh scripts/run.sh --serial 127.0.0.1:5555
sh scripts/run.sh -- --verbose         # anything after -- goes to flutter
```

First run compiles and installs (~1 min warm, ~13 min cold because of Gradle). Afterwards
`r` is a sub-second rebuild.

## Desktop target under Termux:X11

Needs the Termux:X11 app (separate APK) - `pkg install x11-repo` and the GTK libraries are
already there because the Flutter deb depends on them.

```sh
termux-x11 :0 >/dev/null 2>&1 &
export DISPLAY=:0
sh scripts/run.sh --linux
```

Same Dart code, same hot reload, no adb, and the app does not take over the phone screen.
Caveats: rendering goes through GTK/X11 (no Android platform channels, no sensors, no
Android text input quirks), and this path is **not yet verified on this device** - see
`references/limits.md`.

## Tests

```sh
sh scripts/run.sh --test              # flutter test, whole suite
sh scripts/run.sh --test test/x_test.dart
```

`setup.sh` installs a shim (`$PREFIX/lib/libvk_swiftshader.so`) because the deb ships
`flutter_tester` linked against a SwiftShader library it does not contain. With the shim:

- **pure-Dart tests pass** (`test('...', () { ... })`) - verified
- **widget tests crash** with SIGSEGV before the first frame - the stub cannot rasterise.
  `references/limits.md` explains what to do instead (extract logic into plain Dart, verify
  UI on the device).

`flutter analyze` needs nothing extra and is the cheapest quality gate.

## Installing what you built

```sh
sh scripts/install.sh                                  # app-release.apk in the cwd project
sh scripts/install.sh path/to/app.apk
sh scripts/install.sh path/to/app.apk --bg             # background display (root, needs dev-apk skill)
```

Root: stages the APK in `/data/local/tmp` (`system_server` cannot read `/data/data/com.termux`),
`pm install -r -g`, then `am start -W`. No root: `termux-open`, one tap.

## Watching it

```sh
logcat -d | grep -iE 'flutter|AndroidRuntime|FATAL' | tail -40
dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity'
screencap -p /data/local/tmp/s.png
```

A white screen with a clean logcat is the classic gen_snapshot mismatch
(`references/pitfalls.md` #1); a crash on start is usually a missing resource
(`#2`).

## Handing off to the sibling skill

For repeated verification without holding the phone, use `dev-apk-on-android`:

```sh
D=<dev-apk skill>/scripts
sh $D/vd.sh create          # invisible display
sh $D/install.sh app.apk --bg
sh $D/vd.sh shot /sdcard/shot.png
sh $D/vd.sh tap 540 1200
sh $D/log.sh
```

Whether a Flutter/Impeller surface renders on that virtual display is **untested**; the
safe fallback is the real screen plus `screencap`.
