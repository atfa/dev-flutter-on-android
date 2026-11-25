# Changelog

## 0.1.0 - 2026-11-25

First release. Verified on Android 16 (SDK 36), aarch64, 15 GB RAM, KernelSU root.

### Added

- `scripts/setup.sh` - offline install from `vendor/flutter_3.50.1-1_aarch64.deb` (sha256
  checked), Termux dependencies, `post_install.sh`, licence acceptance, `flutter_tester`
  shim, version report, `~/.config/dev-flutter/installed.env`.
  `--fetch` installs from the upstream release instead; `--fix-aapt2` repairs the
  `aapt2 13` -> `16` problem; `--ndk` provisions the aarch64 NDK.
- `scripts/fetch-sdk.sh` - download + verify (sha256 and size) + optional `--install`,
  `--save` to re-vendor a newer tag.
- `scripts/new-project.sh` - `flutter create` + upstream configurator (`aapt2FromMavenOverride`,
  `compileSdk 36`, arm64 only) + Gradle heap cap (`-Xmx3G`, the template ships 8G) +
  gradlew shebang check.
- `scripts/build.sh` - release/debug/aab/linux, arm64 + `--no-tree-shake-icons`, and a
  **structure check** (`AndroidManifest.xml` + `resources.arsc`) that fails the build
  instead of handing over a package that cannot install.
- `scripts/slim-apk.sh` - `llvm-strip` the unstripped engine + repack stored + `zipalign -p 4`
  + re-sign: 167 MB -> 14 MB, verified installing and rendering.
- `scripts/install.sh` - root: staged `pm install -r -g` + `am start -W`; no root:
  `termux-open`; `--bg` delegates to the sibling skill's virtual display.
- `scripts/run.sh` - hot reload on the device (attaches adb itself), `--linux` for the
  Termux:X11 target, `--test` for `flutter test`.
- `scripts/adb-ondevice.sh` - `start|stop|status` for TCP adbd on 127.0.0.1:5555, with the
  security-relevant reset.
- `scripts/fix-tester.sh` + `vendor/vkstub/` - 5 KB `libvk_swiftshader.so` shim in
  `$PREFIX/lib` so `flutter_tester` can start; pure-Dart tests then pass.
- `scripts/doctor.sh` - one screen: aapt2 verdict, SDK layout, Gradle cache, adb, disk,
  Termux:X11 presence.
- `references/` - setup, build, run, pitfalls (symptom -> cause -> fix), limits (verified vs
  not), reuse-dev-apk (division of labour with `dev-apk-on-android`).
- `vendor/SHA256SUMS` + `MANIFEST.md` + `vendor/vkstub/`. The 121 MB `.deb` is a release
  asset (`sdk-3.50.1-1`), fetched by `scripts/fetch-sdk.sh` - GitHub rejects files >100 MB.

### Measured

| step | result |
|---|---|
| deb install + post_install | ~5 min |
| cold release build | 12-14 min |
| warm release build | 45 s |
| cold debug build | 5 min 17 s (679 MB APK) |
| `flutter run` attach | `Syncing files to device` 227 ms |
| slim | 3 s, 167 MB -> 14 MB |
| launch (`am start -W`) | 0.4-0.8 s |

### Known issues

- `flutter test` runs pure-Dart tests only; widget tests SIGSEGV (no real SwiftShader in the
  .deb). See `references/limits.md`.
- Termux:X11 desktop run, native plugins and AAB are implemented but not yet exercised end
  to end on hardware.
