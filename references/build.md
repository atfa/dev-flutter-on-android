# Building

Everything below runs from the project root (`pubspec.yaml` present).

```sh
sh scripts/build.sh release     # default
sh scripts/build.sh debug
sh scripts/build.sh aab
sh scripts/build.sh linux
```

`build.sh` insists that the project is configured (`android.aapt2FromMavenOverride` in
`android/gradle.properties`); if not it runs the upstream configurator first.

## What the configurator changes

`$PREFIX/share/flutter/flutter_project_config.sh <project>` (upstream script, GPL-3, called
- not copied) writes, transactionally with a rollback path:

`android/gradle.properties`
```
android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
```
`android/app/build.gradle.kts`
```
compileSdk = 36
targetSdk = 36
ndk { abiFilters += listOf("arm64-v8a") }
```
`linux/CMakeLists.txt`: `set(CMAKE_SYSTEM_NAME Linux)` prepended.

This is what makes Gradle use Termux's aapt2 instead of downloading Google's x86-64 one.

## Command lines (verified)

```sh
flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
flutter build apk --debug   --target-platform android-arm64
flutter build appbundle --release --target-platform android-arm64 --no-tree-shake-icons
flutter build linux --release
```

Products:

| target | path |
|---|---|
| release APK | `build/app/outputs/flutter-apk/app-release.apk` |
| debug APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Linux bundle | `build/linux/arm64/release/bundle/<app>` |

## Timings (this device, 15 GB RAM)

| build | time |
|---|---|
| cold release (downloads Gradle 9.5 + AGP 9.3 + Kotlin) | 12-14 min |
| warm release after a source change | 40-50 s |
| cold debug (downloads the debug engine + embedding) | 5 min 17 s |
| `flutter build linux --release` | 1-2 min |
| `slim-apk.sh` | 3 s |

The cold build downloads into `~/.gradle` (~1-2 GB). A build that sits at
"Running Gradle task 'assembleRelease'..." for minutes is downloading, not hung.

## The structure check (do not skip)

```sh
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -E 'AndroidManifest.xml|resources.arsc'
```

Both must be listed. Upstream ships `isShrinkResources`/`isMinifyEnabled` off for a reason:
on this toolchain an optimised release build can lose `AndroidManifest.xml` and
`resources.arsc`, and the failure only shows at install time
(`INSTALL_PARSE_FAILED_UNEXPECTED_EXCEPTION`). `build.sh` performs the check and exits
non-zero instead of congratulating you.

## Size: 167 MB is normal, 14 MB is the fixed version

The engine AAR (`io.flutter:arm64_v8a_release`) carries an **unstripped** `libflutter.so`:
161 MB compressed / 170 MB on disk. A normal Flutter install gets stripped by the NDK's
`strip` during packaging; there is no NDK here, so it goes into the APK untouched.

```sh
sh scripts/slim-apk.sh                       # writes app-release-slim.apk
sh scripts/slim-apk.sh my.apk out.apk
```

It unzips `lib/*/*.so`, `llvm-strip --strip-unneeded`s each (libflutter 161 MB -> 10 MB,
libapp 4 MB -> 3 MB), re-adds them stored, `zipalign -f -p 4`s the archive and re-signs
with `~/.android/debug.keystore` (`DEV_FLUTTER_KS`, `DEV_FLUTTER_KS_PASS`,
`DEV_FLUTTER_KS_ALIAS` override it). Verified: the slim APK installs, launches and renders.

A debug APK is **679 MB** - the debug engine is even bigger than the release one and is not
stripped either. `slim-apk.sh` works on it too, but for `flutter run` skip the slimming:
Gradle re-pushes the original on every install.

The Dart AOT snapshot lives inside `libapp.so`'s sections, not in the symbol table that
`--strip-unneeded` removes - stripping it does not change behaviour.

## Signing

Debug keystore by default, created by the first build at `~/.android/debug.keystore`
(password `android`, alias `androiddebugkey`). To ship, add a real keystore to
`android/app/build.gradle.kts` -> `signingConfigs` and use `build.sh aab`; the same
`apksigner` binary works on the APK afterwards.

## Gradle heap

The Flutter 3.50 template writes `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G`,
which is a desktop default - on a phone the daemon gets OOM-killed or pushes everything
else out of memory. `new-project.sh` caps it at `-Xmx3G -XX:MaxMetaspaceSize=1G`
(`--heap 2G` on a smaller device). If you copy a project from a PC, cap it by hand.

## Profile mode

`flutter build apk --profile` works (the Android profile engine is shipped);
`flutter build linux --profile` and `flutter run -d linux --profile` do not - no profile GTK
engine exists in this build.
