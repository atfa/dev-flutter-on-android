# Verified / not verified, and what does not work

## Verified on a real device

Android 16 (SDK 36), aarch64, 15 GB RAM, KernelSU root, Flutter 3.50.1-1, 2026-11-25.

| item | result |
|---|---|
| vendored deb install + `post_install.sh` | ok, `flutter --version` = 3.50.1 / Dart 3.14.0 |
| `flutter doctor -v` | Flutter ✓, Android toolchain ✓ (SDK 36), Linux toolchain ✓, device ✓; Chrome ✗ expected |
| `flutter create` (online) | 14 s |
| upstream configurator on a fresh project | ok (aapt2 override, compileSdk 36, arm64, linux CMake) |
| `flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons` | ok, cold ~13 min, warm 45 s |
| structure check (`AndroidManifest.xml` + `resources.arsc`) | pass |
| install + launch (`pm install -r -g`, `am start -W`) | ok, launch 0.4-0.8 s, renders correctly |
| `slim-apk.sh` (strip + align + sign) | 167 MB -> 14 MB, installs and renders identically |
| `flutter test` on plain `test('...')` | pass (with the tester shim) |
| `adb` over TCP from Termux to its own adbd | `127.0.0.1:5555 device`, key already authorised |
| `flutter run` hot reload on this device | full session: build -> install -> attach (VM service + DevTools), `Syncing files to device 227ms`, `r`/`R` available, clean `q` |
| `flutter build apk --debug` | ok, 5 min 17 s cold, APK is **679 MB** (debug engine is not stripped either) |
| `aapt2 13 -> 16` upgrade path | 13 fails on android-36; 16 needs protobuf/abseil/fmt/libc++ moved together |

## Not verified (do this before trusting the related doc)

| item | how to check | if it fails |
|---|---|---|
| `flutter run -d linux` under Termux:X11 | install Termux:X11, `termux-x11 :0 &`, `DISPLAY=:0 sh scripts/run.sh --linux` | the GTK engine links fine (`ldd` clean), so failures are X11-side |
| Flutter surface on `dev-apk`'s virtual display | `vd.sh create` + `install.sh --bg` + `vd.sh shot` | Impeller/Vulkan may not render on a headless virtual display; fall back to the real screen |
| `flutter build appbundle` | `sh scripts/build.sh aab` | then `bundletool`/Play, not installable directly |
| plugins with native code (`path_provider`, `sqlite3`, …) | add one, `flutter build apk --release` | needs `setup.sh --ndk` + a Gradle/CMake retry |
| `flutter build web` | - | not promised; no Chrome on the device |
| golden tests / `matchesGoldenFile` | - | fonts differ from the recorded goldens anyway |

## Hard limits

- **aarch64 only.** No arm32/x86 APKs (the SDK has no such engine), no iOS/macOS.
- **Widget tests do not run.** `flutter_tester` needs a real `libvk_swiftshader.so`; the deb
  does not ship it and a stub only satisfies the linker. Consequence: keep business logic
  in plain Dart functions/pure blocs (`flutter test` runs those), and verify UI by running
  the app.
- **Not Play-Store grade.** The on-device path turns off R8/resource shrinking and icon
  tree shaking, which is exactly what makes the release build survive on this toolchain.
  For a shippable artifact build the `.aab` in CI with a desktop SDK.
- **`flutter upgrade` is disabled** by the shipped patch. Updates come from the apt repo.
- **One upstream project** (a single maintainer, GitHub Actions + GitHub Pages apt repo).
  The deb is vendored here with its sha256 precisely so the skill keeps working if the
  release disappears.
- **GPL-3 upstream.** `post_install.sh`, `flutter_project_config.sh` and friends are GPL-3.
  This skill is MIT: it **calls** them from `$PREFIX/share/flutter/`, it never vendors them.
- **No 16 KB page-size support in the slim step** (Termux `zipalign` lacks `-P 16`). Fine on
  4 KB devices; skip slimming on 16 KB ones.
