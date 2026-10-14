# Fire OS 5 build

APK for Fire OS 5 devices (Fire TV and Fire tablets that never got Fire OS 6),
which run **Android 5.1, API 22**.

The app is the same one: `flutter/lib` is shared as is, with no changes and no
second copy of the code. Only the way it is built changes, because the Flutter
version of the normal build needs API 24 (Android 7) and its engine does not
even start on API 22.

## What is different

| | Normal APK | This APK |
| --- | --- | --- |
| Flutter | 3.44.4 (minSdk 24) | 3.32.8 (minSdk 21), last series supporting API 21-23 |
| Dart | 3.10 | 3.8 |
| `minSdk` | 24 | 22, passed to Gradle as `-P haimtvMinSdk` |
| Dependencies | `flutter/pubspec.yaml` | `fireos5/pubspec.yaml` |
| Rust library | committed, built for API 24 | rebuilt for API 21 on every build |
| Renderer | Impeller | Skia |
| File name | `HaimTV-<version>-android.apk` | `HaimTV-<version>-android-fireos5.apk` |

Why each one:

- **Dependencies.** `fireos5/pubspec.yaml` keeps the same upper bounds as the
  normal one and only lowers the floors, so pub picks the newest release of
  each package that works on Dart 3.8. As of 1.0.5 that resolves to the very
  same versions as the normal build (media_kit 1.2.6, file_picker 10.3.10,
  device_info_plus 12.4.0, protobuf 6.1.0...), so the two APKs really do
  behave the same. `pubspec.lock` is committed here for the same reason it is
  committed for the normal build.
- **Rust library.** The `.so` files under `flutter/android/app/src/main/jniLibs`
  are built for API 24 and need `getrandom`, `getentropy`, `stdin`, `stderr`
  and `__register_atfork`, none of which exist on Android 5.1: with them the
  app cannot even load. `build.sh` rebuilds the library for API 21 with
  `cargo-ndk` and stages it, without touching the committed one.
- **Impeller.** It needs OpenGL ES 3 and some of these devices only have ES 2
  (the Fire TV Stick 2nd gen among them), so the build asks for Skia with
  `io.flutter.embedding.android.EnableImpeller=false`, injected into the staged
  manifest.
- **Updates.** The in-app update check asks the device for its API level and
  offers the `-fireos5.apk` of the release to anything below API 24, and the
  normal one to the rest (`lib/services/update_checker.dart`). Both APKs are
  signed with the same key and share the application id, so one updates over
  the other.

## Building

Needs the build container (`distrobox enter --name haimdev`) with:

- Flutter 3.32.x in `~/flutter-332` (or `HAIMTV_FLUTTER_332` pointing at it);
  `git clone -b 3.32.8 https://github.com/flutter/flutter.git ~/flutter-332`
- the Android SDK in `~/Android/sdk` and NDK 29 (`ANDROID_NDK_HOME` to use
  another one; API 21 is still supported by it)
- `cargo` and `cargo-ndk` (`cargo install cargo-ndk`)
- `perl-core`, which the vendored OpenSSL of the Android build needs

```sh
fireos5/build.sh
```

It writes `dist/HaimTV-<version>-android-fireos5.apk`, signed with the release
key when `flutter/android/key.properties` is in place, and takes the version
number from `flutter/pubspec.yaml` so both APKs of a release match. Everything
it stages lives in `fireos5/build/` and is not committed.

## Keeping it in sync

Adding a dependency to `flutter/pubspec.yaml` means adding it to
`fireos5/pubspec.yaml` too, with a floor low enough for Dart 3.8, and running
the build once to refresh `fireos5/pubspec.lock`. The build fails loudly if a
package cannot be resolved, so a release never goes out with a stale set.

## What is not covered

- Fire OS 5 was tested on an `android-22` emulator (`default;x86_64`). Those
  devices are 32-bit ARM, and the APK carries `armeabi-v7a`, `arm64-v8a` and
  `x86_64`.
- Android 5.1 ships the root certificates of 2015. HTTPS playlists signed by a
  newer authority (Let's Encrypt's ISRG Root X1, for instance) may be rejected
  on these devices even though they work everywhere else. GitHub, used by the
  update check, still works.
