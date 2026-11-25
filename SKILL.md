---
name: dev-flutter-on-android
description: Build, run and ship Flutter apps entirely on the Android phone from Termux - no PC, no Android Studio, no Gradle install. Use when asked to write a Flutter/Dart app on the device, when a project needs to go from `flutter create` to an APK that installs and does not white-screen, when hot reload is wanted on the phone itself, or when an on-device Flutter build fails (aapt2 cannot load android-36/android.jar, AAPT2/aapt2FromMavenOverride, Gradle wrapper vs AGP version, NDK ENOEXEC, gen_snapshot target_os, blank release APK, missing resources.arsc, INSTALL_PARSE_FAILED, libvk_swiftshader.so, 175 MB APK).
license: MIT
compatibility: Android 11+ (API 30), Termux aarch64 with openjdk-21 + aapt2 >= 16 + apksigner, flutter 3.50.1 from the signed upstream repo (deb vendored here); root (Magisk/KernelSU) optional - improves adb/install/verify; Termux:X11 optional for the desktop target
metadata:
  offline: "yes for the SDK - the 116 MB flutter_3.50.1-1 deb ships in vendor/; the first project still needs pub.dev, and the first build needs Gradle/AGP from the network"
  platforms: android, linux
---

# Flutter on the phone

This skill does **not** build APKs by hand. Gradle + AGP do that on the device already:
`aapt2` (Termux package), `javac`/`d8` (JDK + AGP), zip, and signing all run inside
`flutter build`. The skill's job is the part that is not obvious:

```
sdk        116 MB deb (vendored)                    -> $PREFIX/opt/flutter
sdk fix    post_install.sh (upstream, GPL-3)        -> android-36 platform, engine stamps, patched flutter_tools
project    flutter create + upstream configurator   -> aapt2FromMavenOverride, compileSdk 36, arm64 only
build      flutter build apk --release              -> Gradle: aapt2 + d8 + zip + apksigner
            --target-platform android-arm64
            --no-tree-shake-icons
check      unzip -l | AndroidManifest.xml + resources.arsc      (catches packages that build but cannot install)
shrink     llvm-strip + zipalign -p 4 + apksigner   -> 167 MB APK becomes 14 MB
install    pm install -r -g (root) | termux-open     -> then dumpsys/logcat/screencap
run        flutter run -d 127.0.0.1:5555            -> hot reload on this phone
```

## Quick start

```sh
S=<this skill>/scripts
sh $S/setup.sh                                  # vendored deb, post_install, licences, tester shim
sh $S/new-project.sh $HOME/apps/hello           # create + configure + cap Gradle heap
cd $HOME/apps/hello
sh $S/build.sh release                          # 45 s warm, ~13 min cold (Gradle download)
sh $S/slim-apk.sh                               # 167 MB -> 14 MB
sh $S/install.sh                                # silent install + launch (root)
```

Iterating instead of shipping:

```sh
sh $S/run.sh            # hot reload on this device (attaches adb itself when root)
sh $S/run.sh --linux    # hot reload in a Termux:X11 window instead
sh $S/run.sh --test     # `flutter test` - pure-Dart tests only, see references/limits.md
```

## The four loops

| loop | command | speed | needs |
|---|---|---|---|
| logic | `run.sh --test`, `flutter analyze` | seconds | the tester shim |
| hot reload on device | `run.sh` | seconds after the first build | adb (root: automatic) |
| hot reload on desktop | `run.sh --linux` | seconds | Termux:X11 |
| ship | `build.sh release` → `slim-apk.sh` → `install.sh` | ~1 min warm | nothing |

## Five things that decide success

1. **aapt2 must be >= 16.0.0.4.** The stale `termux.net` mirror still serves 13.0.0.6, which
   fails with `AAPT: error: failed to load include path .../android-36/android.jar`.
   `setup.sh --fix-aapt2` repoints apt at `packages-cf.termux.dev` and moves aapt2 +
   libprotobuf + abseil-cpp + libc++ + fmt **together** (moving them separately gives
   `cannot locate symbol` from the linker). `doctor.sh` prints the verdict.
2. **`--no-tree-shake-icons` on every release build.** Icon tree shaking is restricted by
   JIT Dart and fails the build.
3. **`unzip -l` before installing.** A release package that lost `AndroidManifest.xml` or
   `resources.arsc` builds fine and then fails with `INSTALL_PARSE_FAILED`. `build.sh`
   checks this and refuses to report success.
4. **The APK is 167 MB until you strip it.** The engine comes from Maven **unstripped**
   (170 MB `libflutter.so`); AGP would strip it with the NDK's `strip`, and this SDK has no
   NDK. `slim-apk.sh` does the strip + `zipalign -p 4` + re-sign and gives 14 MB. Verified
   installing and rendering.
5. **`flutter_tester` is missing `libvk_swiftshader.so`.** Without it every `flutter test`
   dies before Dart starts. `setup.sh` installs a 5 KB shim into `$PREFIX/lib` (the binary's
   RUNPATH), which is enough for pure-Dart tests. Widget tests still SIGSEGV on this SDK.

## What this skill will not do

- arm32/x86 APKs, iOS, web (the SDK ships aarch64 only) - `references/limits.md`
- Play-Store-grade release builds: the on-device path disables R8 optimisations and icon
  tree shaking; ship through CI when the app has to pass review
- `flutter upgrade` / `channel` - blocked inside the shipped `flutter_tools` on purpose;
  upgrade with `pkg install flutter`
- widget/golden tests, for now - the engine's SwiftShader is not in the .deb

## References

| file | when |
|---|---|
| `references/setup.md` | installing/repairing the SDK, disk and network budget, offline vendor, upgrading |
| `references/build.md` | build variants, timings, product paths, structure check, slimming, signing |
| `references/run.md` | the three adb routes, hot reload, Termux:X11, installing/launching, logcat |
| `references/pitfalls.md` | symptom -> cause -> fix table, everything measured on a real device |
| `references/limits.md` | what is verified, what is not, and what simply does not work |
| `references/reuse-dev-apk.md` | how this skill hands off to `dev-apk-on-android` (install, virtual display, screenshots) |

## Verified end to end

On Android 16 / aarch64 / KernelSU: vendored install, `doctor`, `create`, configure, release
APK, structure check, install + render, slimming (167 -> 14 MB), pure-Dart tests, and a full
`flutter run` hot-reload session over adb to the phone's own adbd. Not yet exercised:
Termux:X11 desktop window, native plugins, AAB - `references/limits.md`.

## Sibling skill

`dev-apk-on-android` remains the right tool for **plain Java/Go APKs**. It is also the
better *downstream*: its `install.sh`, `vd.sh` (invisible virtual display), `log.sh` and
`screen.sh` drive any Flutter APK. Build with this skill, drive with that one.
