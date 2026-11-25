# Working with `dev-apk-on-android`

Two skills, one phone, different jobs.

| | `dev-apk-on-android` | `dev-flutter-on-android` (this one) |
|---|---|---|
| input | Java/Go sources, `app.env` | a Flutter project (`pubspec.yaml`) |
| build | `aapt2` + `javac` + `d8` by hand | Gradle + AGP inside `flutter build` |
| toolchain | vendored 38 MB (android.jar, r8) | 116 MB Flutter deb + Android SDK assembled by `post_install` |
| output | small APK, no runtime | APK/AAB + Linux bundle |
| sweet spot | tiny tools, Go business logic, JNI, no Gradle | anything Flutter |

## Use the sibling skill *downstream*

Its device-side drivers are runtime-agnostic and better than what a build skill should
re-implement:

```sh
D=<dev-apk skill>/scripts

sh $D/install.sh app.apk            # root: staged pm install + launch; no root: one tap
sh $D/install.sh app.apk --bg       # launch on the invisible virtual display
sh $D/vd.sh create | shot | tap | swipe | text | key | launch
sh $D/log.sh                        # filtered logcat
sh $D/screen.sh                     # screenshot to a file
```

`scripts/install.sh` in this skill is a 40-line subset so the Flutter workflow works
standalone; when both skills are installed, prefer the sibling's (it handles OEM verifier
dialogs and the virtual display).

## Do **not** reuse from the sibling

| component | why not |
|---|---|
| `scripts/build.sh` (aapt2/javac/d8 pipeline) | duplicates Gradle; its `--aapt2` handling and `app.env` SDK levels fight `android.aapt2FromMavenOverride` and `compileSdk` in `build.gradle.kts` |
| `lib/config.sh` + `app.env` | Flutter keeps SDK levels in Gradle, not in an env file |
| `templates/` (Java Activity) | `flutter create` owns the scaffolding |
| `vendor/android.jar`, `vendor/r8-*.jar` | Gradle resolves its own; mixing versions produces confusing dex/resource errors |

## What *is* shareable

- `lib/root.sh` semantics: `have_root` / `asroot` / `asroot_global`. The last one matters on
  KernelSU/Magisk, where a plain `su -c` can see a shadow `/data/data`.
- The staging rule: `system_server` cannot read `/data/data/com.termux`, so any APK handed to
  `pm install` must be copied to `/data/local/tmp` (or `$ANDROID_STAGE_DIR`) and `chmod 644`.
- `vd.sh` caveats from `references/virtual-display.md` (screen-off kills the display, the nav
  bar eats taps near the bottom edge, `input text` is ASCII-only) - all apply to a Flutter
  app as well, *if* it renders there at all (unverified for Impeller surfaces).

## Escalation path

1. Flutter app, needs a package you can install: this skill.
2. Same app, needs unattended verification (screenshot after 3 s, tap a button, assert no
   crash): build here, drive with `dev-apk`'s `vd.sh` + `log.sh`.
3. Needs a Java/Go helper APK instead: the sibling skill.
4. Needs a store-ready artifact: CI with the desktop Flutter SDK, not the phone.
