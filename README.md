# dev-flutter-on-android

Build, run and ship **Flutter** apps on an Android phone from Termux - no PC, no Android
Studio, no Gradle install. Companion to `dev-apk-on-android` (which builds plain
Java/Go APKs by hand; this one drives Gradle instead).

## What it is

An Agent Skill that wraps the cross-built Flutter SDK from
[GeneralKaos666/flutter-for-termux](https://github.com/GeneralKaos666/flutter-for-termux)
(Flutter 3.50.1 / Dart 3.14.0, aarch64), and encodes the parts that cost hours to discover:

- which five project settings make Gradle use Termux's `aapt2` and produce an installable
  package at all
- why `aapt2 13` cannot see `android-36/android.jar`, and how to move the aapt2 stack
  without breaking the linker
- why a release APK is 167 MB (unstripped engine, no NDK `strip`) and the 3-second fix that
  makes it 14 MB
- why `flutter test` cannot even exec (`libvk_swiftshader.so` is missing from the .deb), and
  what that means for widget tests
- how to get hot reload on the phone itself, over adb to its own adbd

## Install

The SDK archive (116 MB) is a release asset of this repo (GitHub caps files at 100 MB, so it
is not in git). One command fetches, verifies and installs it:

```sh
S=scripts
sh $S/fetch-sdk.sh --save             # optional: keep a local copy in vendor/ for offline use
sh $S/setup.sh                        # verify deb -> apt install -> post_install -> licences -> tester shim
sh $S/setup.sh --fix-aapt2            # only if doctor.sh says aapt2 is too old (stale termux.net mirror)
sh $S/doctor.sh                       # one screen: aapt2, SDK, heap, adb, disk
```

`setup.sh` looks for `vendor/flutter_*.deb`; if it is missing it tells you to run
`fetch-sdk.sh`. A newer tag: `FLUTTER_TAG=3.50.2-1 sh $S/fetch-sdk.sh --save`.

## Use

```sh
sh $S/new-project.sh ~/apps/hello     # create + configure + cap Gradle heap
cd ~/apps/hello
sh $S/build.sh release                # ~13 min cold, 45 s warm
sh $S/slim-apk.sh                     # 167 MB -> 14 MB
sh $S/install.sh                      # root: silent install + launch
sh $S/run.sh                          # hot reload on the device
```

## Verified

Android 16 / aarch64 / KernelSU: deb install, `flutter doctor`, `flutter create`, release
APK build, structure check, install + launch + render, slimming, pure-Dart tests, adb over
TCP. See `references/limits.md` for what is **not** verified (hot reload interactively,
Termux:X11 desktop run, native plugins, AAB).

## Layout

```
SKILL.md              agent entry point
README.md             this file
CHANGELOG.md
references/           setup, build, run, pitfalls, limits, reuse-dev-apk
scripts/              setup, fetch-sdk, new-project, build, slim-apk, install, run,
                      adb-ondevice, fix-tester, doctor
lib/                  common.sh (helpers), flutter.sh (env)
vendor/               SHA256SUMS + MANIFEST + vkstub/ (the .deb comes from fetch-sdk.sh)
```

## Licence

MIT. The Flutter SDK and its on-device maintenance scripts
(`$PREFIX/share/flutter/*.sh`) are separate works under their own licences (the SDK is
GPL-3); this skill calls them at runtime and never redistributes them.
