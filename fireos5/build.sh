#!/usr/bin/env bash
# Builds the Haim TV APK for Fire OS 5 (Android 5.1, API 22).
#
# The app itself is the one in flutter/: this script copies that tree, swaps in
# the dependency set of fireos5/pubspec.yaml, rebuilds the Rust library for
# API 21 and builds the APK with an older Flutter. Nothing under flutter/ is
# touched. See fireos5/README.md for the why of each step.
#
# Usage (inside the build container, see README): fireos5/build.sh
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(dirname "$here")
stage="$here/build/app"
libs="$here/build/jniLibs"

# Flutter 3.32 is the last series that still runs on API 21-23.
flutter_sdk=${HAIMTV_FLUTTER_332:-$HOME/flutter-332}
android_sdk=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/sdk}}
ndk=${ANDROID_NDK_HOME:-$android_sdk/ndk/29.0.14206865}
min_sdk=22
ndk_platform=21

die() { echo "fireos5/build.sh: $1" >&2; exit 1; }

[ -x "$flutter_sdk/bin/flutter" ] ||
  die "no Flutter 3.32 in $flutter_sdk (set HAIMTV_FLUTTER_332)"
[ -d "$android_sdk/platforms" ] || die "no Android SDK in $android_sdk"
[ -d "$ndk" ] || die "no NDK in $ndk (set ANDROID_NDK_HOME)"
command -v cargo >/dev/null || die "cargo is not in PATH"
command -v cargo-ndk >/dev/null || die "cargo-ndk is missing (cargo install cargo-ndk)"

flutter_version=$("$flutter_sdk/bin/flutter" --version --machine |
  sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')
case "$flutter_version" in
  3.32.*) ;;
  *) die "expected Flutter 3.32.x in $flutter_sdk, found ${flutter_version:-unknown}" ;;
esac

# Version numbers come from the normal build, so both APKs of a release match.
version=$(sed -n 's/^version: *\([0-9.]*\)+\([0-9]*\) *$/\1 \2/p' "$repo/flutter/pubspec.yaml")
build_name=${version% *}
build_number=${version#* }
[ -n "$build_name" ] && [ -n "$build_number" ] ||
  die "could not read the version from flutter/pubspec.yaml"
echo "==> Haim TV $build_name+$build_number for Fire OS 5 (API $min_sdk)"

echo "==> Rust library for API $ndk_platform"
# The committed libraries under flutter/android are built for API 24 and use
# symbols Android 5.1 has no (getrandom, getentropy, stdin...), so the app
# would not even load with them.
mkdir -p "$libs"
(cd "$repo" && ANDROID_NDK_HOME="$ndk" cargo ndk \
  -t arm64-v8a -t armeabi-v7a -t x86_64 --platform "$ndk_platform" \
  -o "$libs" build --release)

echo "==> Staging the app in ${stage#"$repo/"}"
rm -rf "$stage"
mkdir -p "$stage"
rsync -a --delete \
  --exclude 'build/' --exclude '.dart_tool/' --exclude '.flutter-plugins-dependencies' \
  --exclude 'ios/' --exclude 'macos/' --exclude 'linux/' --exclude 'windows/' \
  --exclude 'pubspec.lock' \
  "$repo/flutter/" "$stage/"
cp "$here/pubspec.yaml" "$stage/pubspec.yaml"
[ -f "$here/pubspec.lock" ] && cp "$here/pubspec.lock" "$stage/pubspec.lock"
cp -r "$libs/." "$stage/android/app/src/main/jniLibs/"
printf 'flutter.sdk=%s\nsdk.dir=%s\n' "$flutter_sdk" "$android_sdk" \
  > "$stage/android/local.properties"

# Impeller needs OpenGL ES 3, which the GPUs of these devices do not all have
# (the Fire TV Stick 2nd gen is ES 2 only), and it would render nothing. Skia
# is still available in this Flutter version.
python3 - "$stage/android/app/src/main/AndroidManifest.xml" <<'PY'
import io, sys
path = sys.argv[1]
manifest = io.open(path, encoding="utf-8").read()
tag = "io.flutter.embedding.android.EnableImpeller"
if tag not in manifest:
    anchor = "    </application>"
    assert manifest.count(anchor) == 1, "unexpected AndroidManifest.xml"
    manifest = manifest.replace(anchor, (
        '        <!-- Fire OS 5 build: these GPUs predate the OpenGL ES 3\n'
        '             that Impeller needs, so rendering falls back to Skia. -->\n'
        '        <meta-data\n'
        '            android:name="' + tag + '"\n'
        '            android:value="false" />\n' + anchor))
    io.open(path, "w", encoding="utf-8").write(manifest)
    print("    Impeller disabled in the staged manifest")
PY

echo "==> flutter pub get"
cd "$stage"
if [ -f pubspec.lock ]; then
  "$flutter_sdk/bin/flutter" pub get --enforce-lockfile
else
  "$flutter_sdk/bin/flutter" pub get
fi

echo "==> flutter build apk"
"$flutter_sdk/bin/flutter" build apk --release \
  --build-name="$build_name" --build-number="$build_number" \
  -P haimtvMinSdk="$min_sdk"

out="$repo/dist/HaimTV-$build_name-android-fireos5.apk"
mkdir -p "$repo/dist"
cp "$stage/build/app/outputs/flutter-apk/app-release.apk" "$out"
echo "==> ${out#"$repo/"}"
"$android_sdk"/build-tools/*/aapt dump badging "$out" 2>/dev/null |
  sed -n 's/^package: //p;s/^sdkVersion/sdkVersion/p;s/^targetSdkVersion/targetSdkVersion/p' | head -3 || true
