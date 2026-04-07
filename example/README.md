# vision-camera-payment-card-scanner example

This example app demonstrates how to use `react-native-vision-camera-payment-card-scanner` on both iOS and Android.

It is a development/demo app for the library in the parent directory.

## What the example demonstrates

The app currently includes:

- parser smoke-test output
- native support check via `isSupported()`
- camera permission handling
- live camera preview
- still-image capture and scan flow
- platform-specific scanning behavior

## Platform behavior

| Platform | Demo behavior |
|---|---|
| iOS | live VisionCamera preview with `scanPaymentCard(frame, options?)` frame processing, plus still-image capture for comparison |
| Android | live camera preview, still-image capture, then `scanCardImage(...)` using ML Kit OCR |

## Current architecture in the example

### iOS

The iOS demo shows the most advanced flow currently available in the project:

- live camera preview
- VisionCamera frame processor worklet
- native `scanPaymentCard(frame, options?)`
- still-image capture path for comparison

### Android

The Android demo currently uses:

- live camera preview
- still-image capture with VisionCamera
- `scanCardImage({ imageUri })`
- Android native ML Kit OCR

### Not currently implemented on Android

The example does **not** currently demonstrate:

- Android live frame scanning
- Android native `scanCard()` camera-capture flow

For Android, the intended demo path is:

```text
preview -> capture photo -> scanCardImage(imageUri) -> ML Kit OCR -> CardScanResult
```

## Example app UI sections

The current demo UI includes these sections:

### Parser smoke test

Shows the JavaScript parser helpers using a sample PAN and expiry value:

- normalized PAN
- last4
- brand detection
- Luhn validation result
- parsed expiry

### Camera scanning demo

Shows:

- native support state
- camera permission state
- camera preview
- live frame result area
- last captured image URI
- still-image scan result

## Running the example

From the project root:

```sh
yarn install
```

## Start Metro

From the project root:

```sh
yarn example start
```

## Run iOS

From the project root:

```sh
yarn example ios
```

### iOS notes

Make sure CocoaPods dependencies are installed and up to date when native dependencies change.

Typical flow:

```sh
cd example/ios
bundle install
bundle exec pod install
```

The iOS example requires camera permission. The example app includes `NSCameraUsageDescription` in `Info.plist`.

## Run Android

From the project root:

```sh
yarn example android
```

### Android notes

The Android example requires camera permission for the preview/capture demo flow.

The example app manifest includes:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

If permission gets stuck in a denied state, uninstall and reinstall the example app or re-enable camera access in Android Settings.

## Key APIs used in the example

The example app imports and exercises these library APIs:

- `isSupported()`
- `scanCardImage(...)`
- `scanPaymentCard(frame, options?)`
- `normalizePan(...)`
- `getLast4(...)`
- `detectBrand(...)`
- `parseExpiry(...)`
- `isValidLuhn(...)`

## Typical usage flows shown

### iOS live frame flow

```text
Camera preview -> useFrameProcessor -> scanPaymentCard(frame, options) -> live CardScanResult updates
```

### Cross-platform still-image flow

```text
takePhoto() -> build file:// URI -> scanCardImage({ imageUri }) -> CardScanResult
```

## Troubleshooting

### Android says camera permission is denied

Check:

- app has been rebuilt after manifest changes
- camera permission is enabled in Android Settings
- device has a back camera available

### Android capture fails with camera closed

The example app should keep the preview active during capture.
If this reappears, rebuild the app and retry.

### Android scan result is incomplete

ML Kit OCR quality depends on:

- sharp focus
- good lighting
- visible card number
- minimal glare
- card roughly filling the frame

### iOS frame processor does not work

Confirm:

- `react-native-vision-camera` is installed
- `react-native-worklets-core` is installed
- pods are installed
- the app has camera permission

## Security notes

Even in the demo app, follow safe handling rules:

- do not log full PANs
- do not log raw OCR text
- do not store captured images longer than needed
- do not scan CVV

If debugging card values, prefer masked output such as:

```text
************1111
```

## Source locations

Useful files in the example app:

| File | Purpose |
|---|---|
| `/a0/usr/projects/vision-camera-payment-card-scanner/example/src/App.tsx` | main demo UI and scan flow |
| `/a0/usr/projects/vision-camera-payment-card-scanner/example/android/app/src/main/AndroidManifest.xml` | Android app permissions |
| `/a0/usr/projects/vision-camera-payment-card-scanner/example/ios/VisionCameraPaymentCardScannerExample/Info.plist` | iOS camera permission |

## Related documentation

- main library README: `/a0/usr/projects/vision-camera-payment-card-scanner/README.md`
- React Native docs: https://reactnative.dev
- VisionCamera docs: https://react-native-vision-camera.com
