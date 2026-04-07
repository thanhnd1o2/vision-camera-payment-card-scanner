# react-native-vision-camera-payment-card-scanner

`react-native-vision-camera-payment-card-scanner` is a React Native library for native payment card scanning.

It provides:

- payment card number extraction
- expiry date parsing
- card brand detection
- Luhn validation
- structured scan results for React Native apps
- optional cardholder name extraction

The library is intentionally **platform-specific**:

- **iOS** uses a native VisionCamera frame processor backed by Apple Vision-based scanning logic.
- **Android** currently uses **ML Kit OCR on still images**.

## Current platform status

| Platform | Status | Main scanning path |
|---|---|---|
| iOS | implemented | live VisionCamera frame processor via `scanPaymentCard(frame, options?)` |
| iOS | implemented | still-image scanning helper via `scanCardImage(...)` |
| Android | implemented | still-image OCR via `scanCardImage(...)` and ML Kit |
| Android | not implemented yet | full native `scanCard()` capture flow |

## Installation

Install the package and required peers:

```sh
npm install react-native-vision-camera-payment-card-scanner react-native-vision-camera react-native-worklets-core
```

or:

```sh
yarn add react-native-vision-camera-payment-card-scanner react-native-vision-camera react-native-worklets-core
```

### Peer dependencies

This library expects these peer dependencies in your app:

- `react`
- `react-native`
- `react-native-vision-camera`
- `react-native-worklets-core`

## iOS requirements

For the live frame processor path on iOS, your app must be configured for:

- `react-native-vision-camera`
- `react-native-worklets-core`
- camera permission in `Info.plist`

Typical permission key:

```xml
<key>NSCameraUsageDescription</key>
<string>We use the camera to scan payment cards.</string>
```

## Android requirements

Android currently supports **captured-image OCR** using ML Kit.

Your app should declare camera permission if you use a camera preview or capture flow in your app UI:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Note:

- Android **does not currently implement** a full native `scanCard()` camera flow in this library.
- The active Android path is `scanCardImage(...)`.

## API

### Types

```ts
export type CardBrand = 'visa' | 'mastercard' | 'amex' | 'unknown'

export type CardScanResult = {
  pan?: string
  last4?: string
  expiryMonth?: number
  expiryYear?: number
  brand?: CardBrand
  cardholderName?: string
  complete: boolean
}

export type ScanCardOptions = {
  scanExpiry?: boolean
  restrictToBrands?: CardBrand[]
}

export type CardImageScanOptions = ScanCardOptions & {
  imageUri: string
}
```

### `isSupported()`

Checks whether the current native environment is supported.

```ts
import { isSupported } from 'react-native-vision-camera-payment-card-scanner'

const supported = await isSupported()
```

### `scanCard(options?)`

```ts
import { scanCard } from 'react-native-vision-camera-payment-card-scanner'

const result = await scanCard({
  scanExpiry: true,
  restrictToBrands: ['visa'],
})
```

#### Current behavior

| Platform | Behavior |
|---|---|
| iOS | native module path available |
| Android | currently rejects with an unsupported error for ML Kit option 2 |

If you need Android scanning today, use `scanCardImage(...)`.

### `scanCardImage(options)`

Scans a captured still image.

```ts
import { scanCardImage } from 'react-native-vision-camera-payment-card-scanner'

const result = await scanCardImage({
  imageUri: 'file:///path/to/photo.jpg',
  scanExpiry: true,
  restrictToBrands: ['visa'],
})
```

#### Current behavior

| Platform | Behavior |
|---|---|
| iOS | supported |
| Android | supported via ML Kit OCR |

### `scanPaymentCard(frame, options?)`

This is the advanced **iOS live frame processor** API for VisionCamera worklets.

```ts
import { scanPaymentCard } from 'react-native-vision-camera-payment-card-scanner'
```

```ts
const result = scanPaymentCard(frame, {
  scanExpiry: true,
  restrictToBrands: ['visa'],
})
```

#### Current behavior

| Platform | Behavior |
|---|---|
| iOS | supported |
| Android | not used in the current demo/implementation |

## Cardholder name support

`cardholderName` is returned as a **best-effort OCR hint** on supported native scan paths.

Notes:

- it is optional and may be omitted
- it does not currently affect `complete`
- it is derived heuristically from OCR text and is less reliable than PAN or expiry

## Parser utilities

The package also exports parser helpers for normalization and validation:

- `normalizePan(...)`
- `getLast4(...)`
- `detectBrand(...)`
- `parseExpiry(...)`
- `isValidLuhn(...)`

Example:

```ts
import {
  normalizePan,
  getLast4,
  detectBrand,
  parseExpiry,
  isValidLuhn,
} from 'react-native-vision-camera-payment-card-scanner'

const pan = normalizePan('4111 1111 1111 1111')
const last4 = getLast4(pan)
const brand = detectBrand(pan)
const expiry = parseExpiry('04/29')
const valid = isValidLuhn(pan)
```

## iOS live frame processor example

A typical VisionCamera integration looks like this:

```tsx
import { useMemo } from 'react'
import { Camera, useCameraDevice, useFrameProcessor } from 'react-native-vision-camera'
import { useRunOnJS } from 'react-native-worklets-core'
import {
  scanPaymentCard,
  type CardScanResult,
  type ScanCardOptions,
} from 'react-native-vision-camera-payment-card-scanner'

const options: ScanCardOptions = {
  scanExpiry: true,
}

export function CardScanner() {
  const device = useCameraDevice('back')

  const updateResult = useRunOnJS((result: CardScanResult | null) => {
    console.log(result)
  }, [])

  const frameProcessor = useFrameProcessor((frame) => {
    'worklet'
    const result = scanPaymentCard(frame, options)
    if (result != null) {
      updateResult(result)
    }
  }, [updateResult])

  if (!device) {
    return null
  }

  return (
    <Camera
      device={device}
      isActive={true}
      style={{ flex: 1 }}
      photo={true}
      frameProcessor={frameProcessor}
    />
  )
}
```

## Cross-platform still-image example

```ts
import { scanCardImage } from 'react-native-vision-camera-payment-card-scanner'

async function scanCapturedImage(imageUri: string) {
  return scanCardImage({
    imageUri,
    scanExpiry: true,
  })
}
```

This is currently the recommended Android path.

## Android notes

Android currently uses **ML Kit text recognition** on captured still images.

### Supported Android path today

```text
capture photo -> scanCardImage({ imageUri }) -> ML Kit OCR -> parser -> CardScanResult
```

### Not implemented yet

The following Android feature is not yet implemented in the library:

```text
scanCard() -> launch native Android camera flow -> live/native card scan
```

If you need Android scanning right now, capture an image in your app and pass its file URI to `scanCardImage(...)`.

## Result semantics

A scan result looks like:

```ts
{
  pan?: string
  last4?: string
  expiryMonth?: number
  expiryYear?: number
  brand?: 'visa' | 'mastercard' | 'amex' | 'unknown'
  complete: boolean
}
```

### `complete`

`complete` is `true` when the library has enough high-confidence information for a usable card result.

In practice this typically means:

- a valid PAN candidate was found
- Luhn validation passed
- expiry was found when expiry scanning was requested

## Security notes

This library is designed with payment-card safety in mind.

### Recommended rules

- never log full PANs
- never log raw OCR text
- never store raw camera frames
- never persist captured images longer than needed
- never scan or store CVV

Use masked PAN values for debugging, for example:

```text
************1111
```

## Limitations

### iOS

- live frame scanning is the most advanced path
- still-image path is also available
- real-world OCR quality depends on lighting, focus, angle, and card visibility

### Android

- current implementation is still-image OCR only
- no Android live frame scanning path is enabled yet
- no Android native `scanCard()` camera capture workflow yet
- OCR quality depends on capture quality, lighting, and visible card text

## Example app

The repository includes an example app under:

- `/example`

Current demo behavior:

| Platform | Demo behavior |
|---|---|
| iOS | live frame scanning plus still-image comparison |
| Android | camera preview + capture still image + ML Kit OCR |

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
