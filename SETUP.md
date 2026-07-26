# Native project setup (Android / iOS)

This zip ships `pubspec.yaml`, `lib/`, `test/`, and — in `platform_reference/`
— the two native files every dependency here actually requires you to
edit by hand:

- `platform_reference/AndroidManifest.xml`
- `platform_reference/Info.plist`

It does **not** ship the rest of the native Android/iOS project
scaffolding (Gradle wrapper `.jar`, `settings.gradle`, `build.gradle`
files, the Xcode `Runner.xcodeproj/project.pbxproj`, `Podfile`,
`MainActivity.kt`, `AppDelegate.swift`, launch storyboards, etc.). Those
are binary or extremely fragile generated-ID formats — hand-writing them
as plain text risks a corrupted, un-openable Xcode project or a Gradle
build using the wrong toolchain. The only reliable way to produce them
is Flutter's own project generator, which is why the setup below starts
with `flutter create`.

## One-time setup (run once, in order)

```bash
unzip setrize_studio.zip
cd setrize_studio

# 1. Generate the real android/ and ios/ native scaffolding. Since
#    pubspec.yaml + lib/ already exist, this only adds the platform
#    folders — it will not touch your Dart code.
flutter create --org com.setrize --project-name setrize .

# 2. Copy the pre-filled permission files from platform_reference/ over
#    Flutter's bare defaults (which request zero permissions).
cp platform_reference/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp platform_reference/Info.plist ios/Runner/Info.plist

# 3. Install packages and generate Freezed/Drift/Riverpod code.
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 4. Run on a real device — see the camera note below.
flutter run
```

## Required manual edits after `flutter create`

### `android/app/build.gradle`
Set the minimum SDK version. `camerawesome` requires 21+; 23 is what
Google's own docs specify for `google_mlkit_face_detection`, so it
covers every dependency in this project:

```gradle
android {
    defaultConfig {
        minSdkVersion 23
        // compileSdkVersion / targetSdkVersion: leave whatever
        // `flutter create` generated — Flutter keeps these current.
    }
}
```

### `ios/Podfile`
Set the deployment target to iOS 15.5+, required because
`google_mlkit_face_detection`'s native library is 64-bit only:

```ruby
platform :ios, '15.5'
```

### Xcode — exclude armv7
ML Kit's native binaries don't support 32-bit architectures. In Xcode:
`Runner target → Build Settings → Excluded Architectures → Any SDK → armv7`.
(Only matters for `flutter build ios`/`ipa`; `flutter run` in debug on a
64-bit device works without this step.)

## Testing notes

- **Camera**: `camerawesome` needs a **real device** for reliable
  results. The iOS Simulator has no camera hardware at all; some
  Android emulators expose a fake camera feed, enough to test
  navigation but not real capture quality.
- **Upload**: `kDemoMode = true` in
  `lib/features/studio/state/studio_providers.dart` fakes the upload
  step so you can test camera → editor → preview → "share" end-to-end
  without a backend. Set it to `false` and point `kUploadEndpoint` at
  your real API when ready.
