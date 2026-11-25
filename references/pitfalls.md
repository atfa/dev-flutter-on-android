# Pitfalls (symptom -> cause -> fix)

Everything marked **[v]** was reproduced on Android 16 / aarch64 / Flutter 3.50.1-1 while
writing this skill. The rest comes from upstream's docs, issues and source.

## 1. The aapt2 family

| # | symptom | cause | fix |
|---|---|---|---|
| 1.1 **[v]** | `AAPT: error: failed to load include path /…/android-sdk/platforms/android-36/android.jar`, `processReleaseResources` fails after ~13 min | Termux's `aapt2 13.0.0.6` cannot read the android-36 jar. It comes from the stale `termux.net` mirror | `sh scripts/setup.sh --fix-aapt2` (pins apt at `packages-cf.termux.dev`, upgrades the aapt2 stack). Stopgap: `TERMUX_COMPILE_SDK=35` + install platform 35 |
| 1.2 **[v]** | after upgrading aapt2 alone: `CANNOT LINK EXECUTABLE "aapt2": cannot locate symbol "_ZN6google8protobuf2io19ZeroCopyInputStream8ReadCordE…"`, then the same for `fmt::vformat` | aapt2 16 links the new protobuf/abseil/fmt/libc++ ABI | move them **together**: `apt-get install -y aapt2 libprotobuf abseil-cpp libc++ fmt` |
| 1.3 | `error: failed to load include path` even with aapt2 16 | wrong `android.aapt2FromMavenOverride` (path typo) or the project was never configured | `flutter_project_config.sh <proj>`; check `grep aapt2FromMavenOverride android/gradle.properties` |
| 1.4 **[v]** | `apt` dies mid-download with `SSL connection failed: error:0A000126:…unexpected eof`, 40+ files fail, nothing installs | the TLS path to `packages-cf.termux.dev` breaks on large files on some networks | retry `pkg update && apt-get upgrade`; or download the .deb with `curl` and `apt install ./file.deb` (curl succeeded at 2.3 MB/s where apt failed) |

## 2. Build-time

| # | symptom | cause | fix |
|---|---|---|---|
| 2.1 **[v]** | build "hangs" at `Running Gradle task 'assembleRelease'...` | first build downloads Gradle 9.5 + AGP 9.3 + Kotlin (~1 GB) | wait. Cold 12-14 min, warm 45 s |
| 2.2 **[v]** | `:app:processReleaseResources` fails on a *fresh* `flutter create` project | project not configured for Termux | run the configurator (`new-project.sh` does it) |
| 2.3 **[v]** | Gradle daemon killed / phone unusable during build | template `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G` | `new-project.sh` caps it at `-Xmx3G`; do the same on copied projects |
| 2.4 | icon tree-shaking build error | JIT Dart restriction | always `--no-tree-shake-icons` on release |
| 2.5 | `Minimum supported Gradle version is 9.3.1. Current version is 8.10.2` (upstream issue #43) | old template vs AGP 9.x | **not reproduced on 3.50.1-1**: the template ships `gradle-9.5.0` + AGP 9.3.1. If it appears, edit `android/gradle/wrapper/gradle-wrapper.properties` -> `gradle-9.3.1-bin.zip` |
| 2.6 | `NDK … did not have a source.properties`, `Could not find toolchain file`, `Syntax error: ")" unexpected`, `ENOEXEC` | AGP grabbed an **x86_64** NDK and tried to exec it | `post_install.sh --provision-ndk` (aarch64 r30). Pure-Dart apps need no NDK at all |
| 2.7 **[v]** | warning: `Platform-Tools v.37.0.3 … already exists. Installing in "platform-tools-2"` | AGP insists on its own platform-tools next to Termux's symlink | harmless; delete `$PREFIX/opt/android-sdk/platform-tools-2` if it bothers you |
| 2.8 | `PLATFORM_ABI_LIST` unresolved in Kotlin | stale Gradle plugin cache after a post_install patch | re-run `post_install.sh`, delete `~/.gradle/caches`, `android/.gradle`, `build` |
| 2.9 | `flutter build linux --profile` fails | no profile GTK engine in this build | use `--release` (or debug) |

## 3. Package-time

| # | symptom | cause | fix |
|---|---|---|---|
| 3.1 **[v]** | release APK is 167-175 MB | the Maven engine ships an **unstripped** `libflutter.so` (170 MB) and there is no NDK `strip` | `sh scripts/slim-apk.sh` -> 14 MB, verified installing |
| 3.2 | `INSTALL_PARSE_FAILED_UNEXPECTED_EXCEPTION`, `Failed to read manifest` | optimised resource shrinking dropped `AndroidManifest.xml` / `resources.arsc` | check with `unzip -l`; keep `isMinifyEnabled=false`, `isShrinkResources=false`, `android.enableResourceOptimizations=false` |
| 3.3 | APK installs, opens to a **white screen**, logcat clean | `gen_snapshot` built for `target_os=linux` instead of android (old deb / self-built) | upgrade to >= 3.50.0-6; `flutter clean`; check `bin/cache/artifacts/engine/linux-arm64-android-release/gen_snapshot` exists |
| 3.4 **[v]** | `su -c "cp ~/x"` fails with `bad '//tmp/…'` | `su` runs with `HOME=/`, so `~` is `/` | always pass absolute paths into `su -c` |
| 3.5 **[v]** | `pm install` works but the app cannot read its own assets | root-created files land as 600 in the app's dir / a shadow `/data/data` on KernelSU | stage in `/data/local/tmp` with `chmod 644` |
| 3.6 | `pm install` never returns (OEM verifier dialog) | Play Protect turns install into a UI prompt | `dev-apk-on-android/scripts/silent-install.sh` disables the verifier and retries |

## 4. Test-time

| # | symptom | cause | fix |
|---|---|---|---|
| 4.1 **[v]** | every `flutter test` fails: `CANNOT LINK EXECUTABLE "flutter_tester": library "libvk_swiftshader.so" not found` | the .deb ships `flutter_tester` with `DT_NEEDED libvk_swiftshader.so` but not the library | `sh scripts/fix-tester.sh` (5 KB shim in `$PREFIX/lib`, which is the binary's RUNPATH) |
| 4.2 **[v]** | pure-Dart tests pass, `testWidgets` dies with `Shell subprocess crashed with segmentation fault` and repeated `Fontconfig error: No writable cache directories` | the shim cannot rasterise; the generated fontconfig tries `/var/cache/fontconfig`, which is read-only on Android | do not use widget tests on this SDK - extract logic, test it as plain Dart, verify UI on the device (`references/limits.md`) |
| 4.3 | `flutter test` works, then breaks after an SDK update | `flutter precache` / reinstall restored the original `flutter_tester` and/or removed the shim | re-run `scripts/fix-tester.sh` |

## 5. Project and workflow

| # | symptom | cause | fix |
|---|---|---|---|
| 5.1 **[v]** | `flutter create --offline` -> `Because … depends on flutter_lints any which doesn't exist (could not find package flutter_lints in cache), version solving failed` | `--offline` only works once `~/.pub-cache` is warm | first project online; `--offline` afterwards |
| 5.2 | `flutter upgrade` / `downgrade` / `channel` exit 1 | blocked inside the shipped `flutter_tools` (the SDK is a cross-built tree, not a git checkout) | `pkg install flutter` (apt repo) or reinstall the deb |
| 5.3 **[v]** | `flutter doctor` says `Some Android licenses not accepted` right after `post_install` claimed it accepted them | `sdkmanager --licenses` and flutter's own check disagree | `yes \| flutter doctor --android-licenses` (`setup.sh` does it) |
| 5.4 **[v]** | `flutter doctor` shows `Chrome ✗` and `unknown channel` | no browser; the SDK is not a git checkout | both expected, not errors |
| 5.5 | everything broke after a `pkg upgrade` | Termux is rolling; protobuf/libc++/fmt sonames moved under the SDK | `pkg update && pkg upgrade` **the whole system** (partial upgrades are what break), then `post_install.sh` + `setup.sh --fix-aapt2` |
| 5.6 **[v]** | `gradlew: bad interpreter` on a project copied from a PC | shebang is `#!/usr/bin/env bash` | `sed -i '1s|.*|#!/data/data/com.termux/files/usr/bin/bash|' android/gradlew` |
| 5.7 | `No space left on device` | Gradle + pub + SDK ≈ 3.5 GB | `pkg clean`, clear `~/.gradle/caches`, `~/.pub-cache/hosted` |
| 5.8 **[v]** | `flutter run` says no device | Termux's adb has no device attached | `sh scripts/adb-ondevice.sh start` (root) or wireless-debugging pairing |
| 5.9 **[v]** | scripts writing to `/tmp` fail with `Permission denied` | Termux has no writable `/tmp` | use `$TMPDIR` (`$PREFIX/tmp`) |
| 5.11 **[v]** | `Could not resolve …: (internal_error) java.security.InvalidAlgorithmParameterException: the trustAnchors parameter must be non-empty` - Gradle cannot download anything, even though `curl` works | the JDK has no trust store: `$PREFIX/etc/tls/certs/java/cacerts` is missing and the `ca-certificates-java` package is stale | `pkg install ca-certificates-java` (regenerates 118 CAs), then `pkill -f GradleDaemon` so the daemon forgets the empty store |
| 5.12 **[v]** | debug APK is 679 MB | debug engine is unstripped like the release one | expected; use `flutter run` (pushes once) or `slim-apk.sh` for a package you keep |
| 5.10 | 16 KB page-size devices refuse the slim APK | Termux's `zipalign` has no `-P 16`, so `.so` files are 4 KB aligned | check `getconf PAGE_SIZE`; if 16384, skip `slim-apk.sh` (or use a newer `zipalign`) |
