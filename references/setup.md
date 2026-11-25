# Installing the Flutter SDK on the device

## What you get

Flutter 3.50.1 / Dart 3.14.0, cross-built for Android/Termux, aarch64 only, in
`$PREFIX/opt/flutter` (~930 MB on disk) plus `$PREFIX/share/flutter/` (the upstream
maintenance scripts) and `$PREFIX/opt/android-sdk` (~460 MB).

Engine slots that matter:

| slot | mode | used by |
|---|---|---|
| `linux-arm64/` | debug GTK | `flutter run -d linux` (JIT, hot reload), `flutter test` |
| `linux-arm64-release/` | release GTK | `flutter build linux --release` |
| `linux-arm64-android-release/` + `-profile/` | Android AOT `gen_snapshot` | `flutter build apk/appbundle --release|--profile` |

There is no `linux-arm64-profile` (upstream stopped building it) and no arm32/x86 engine.

## Route 1: vendored .deb (default, offline)

```sh
sh scripts/setup.sh
```

- verifies `vendor/flutter_3.50.1-1_aarch64.deb` against `vendor/SHA256SUMS`
  (`2d4f837c…a2e3`, 121,286,712 bytes)
- `pkg install` for `x11-repo` (Pre-Depends), `openjdk-21`, `aapt2`, `apksigner`,
  `android-tools`, `zip`, `git`, `cmake`, `ninja`, `pkg-config`, `clang`; the deb itself
  pulls `gtk3`, `xorgproto`, `wget`, `curl`, `7zip`, `binutils`, `tar`, `xz-utils`
- `apt install ./flutter_3.50.1-1_aarch64.deb` - the postinst runs `post_install.sh`
- accepts the Android licences, installs the `flutter_tester` shim, prints the versions
  and writes `~/.config/dev-flutter/installed.env`

Re-running it is safe and is the fix for most "it worked yesterday" states.

## Route 2: the upstream apt repository (updates)

```sh
pkg install -y gnupg x11-repo
curl -fsSL https://generalkaos666.github.io/termux-apt-repo/key.gpg \
  -o "$PREFIX/etc/apt/keyrings/termux-apt-repo.gpg"
gpg --show-keys --with-fingerprint "$PREFIX/etc/apt/keyrings/termux-apt-repo.gpg"
# must print: 1DED 0840 4574 B867 B058 A7BB 476F C230 ECBB FDF0
echo "deb [signed-by=$PREFIX/etc/apt/keyrings/termux-apt-repo.gpg] \
https://generalkaos666.github.io/termux-apt-repo stable main" \
  >"$PREFIX/etc/apt/sources.list.d/termux-apt-repo.list"
pkg update && pkg install flutter
```

The repo package is a 3.8 KB stub; it downloads the 116 MB archive from the GitHub release
on install. Afterwards upgrades are `pkg install flutter` - **never `flutter upgrade`**
(patch inside the shipped `flutter_tools`: exit 1, by design).

## Route 3: manual, pinned

```sh
sh scripts/fetch-sdk.sh --install                 # downloads, verifies sha256 + size, installs
sh scripts/fetch-sdk.sh --save                    # drop it into vendor/ to go offline again
FLUTTER_TAG=3.50.2-1 sh scripts/fetch-sdk.sh      # a newer tag
```

## What `post_install.sh` actually does

17 idempotent steps (`$PREFIX/share/flutter/post_install.log`): fake `engine.stamp`/`realm`
because the SDK is not a git checkout, download the official Dart snapshots, clean ELFs,
install the Android SDK platform (36 -> 35 -> 34 fallback) plus build-tools/platform-tools/
cmdline-tools, accept licences, regenerate `flutter_tools`' `package_config.json`, drop the
Flutter Gradle plugin cache, point `~/.flutter_settings` at the SDK, patch
`compileSdk`/`abiFilters`/script shebangs, pin the channel to stable.

`--provision-ndk` adds a ~550 MB aarch64 NDK (r30). Only needed when a plugin has native
code; a pure-Dart app builds without one.

## Budget (measured on a 15 GB / Android 16 phone)

| step | time | bytes |
|---|---|---|
| vendored deb install + post_install | ~5 min | 116 MB local |
| first `flutter --version` (builds the tool) | 25 s | - |
| first `flutter create` (pub.dev) | 14 s | ~10 MB |
| first release build (Gradle 9.5 + AGP 9.3 download) | **~13 min** | ~1 GB in `~/.gradle` |
| warm release build | 45 s | - |
| `slim-apk.sh` | 3 s | - |
| disk after everything | - | flutter 930 MB + sdk 460 MB + gradle 2 GB |

## Verify

```sh
flutter --version            # Flutter 3.50.1 • Dart 3.14.0
flutter doctor -v
sh scripts/doctor.sh
```

Expected `flutter doctor` output on a healthy device: Flutter ✓, Android toolchain ✓ (SDK
36, build-tools 35/36), Linux toolchain ✓, Connected device ✓ (Linux desktop). Expected
complaints: **Chrome ✗** (no browser) and, before the licences are accepted, "some Android
licenses not accepted".

## Repair

| symptom | do |
|---|---|
| any Gradle/engine weirdness after a `pkg upgrade` | `bash $PREFIX/share/flutter/post_install.sh` |
| `aapt2` too old / cannot load android.jar | `sh scripts/setup.sh --fix-aapt2` |
| `flutter` starts but `flutter test` cannot exec | `sh scripts/fix-tester.sh` |
| SDK badly broken | `apt remove flutter && sh scripts/setup.sh` |
| out of space | `pkg clean`, `rm -rf ~/.gradle/caches`, `rm -rf ~/.pub-cache/hosted` |

## Uninstall

```sh
apt remove flutter          # leaves ~/.gradle and ~/.pub-cache
rm -rf $PREFIX/opt/android-sdk $PREFIX/share/flutter   # if you want the SDK gone too
```
