# Smart Scanner

A Flutter app that scans **credit/debit cards** and **bank passbooks** using the device camera and on-device OCR — no internet connection required for scanning.

---

## Steps to Run the Project

### Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Flutter SDK | 3.5.0 |
| Dart SDK | 3.5.0 |
| Android Studio / Xcode | Latest stable |
| Physical device (recommended) | Android 6+ / iOS 13+ |

> **Note:** A physical device is strongly recommended because the `camera` plugin does not work reliably on emulators/simulators. ML Kit text recognition also performs significantly better on real hardware.

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd smart_scanner
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Android — Grant Permissions

The app requires camera and media-image access. These are declared in `AndroidManifest.xml` and requested at runtime via `permission_handler`. No manual setup is needed beyond accepting the prompt on first launch.

### 4. iOS — Info.plist Keys

Ensure the following keys are present in `ios/Runner/Info.plist` (they are already included in this repo):

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan cards and passbooks.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Gallery access is used to pick an image for scanning.</string>
```

### 5. Run

```bash
# List connected devices
flutter devices

# Run on a specific device
flutter run -d <device-id>

# Release build (Android)
flutter build apk --release
```

### 6. Run Tests

```bash
flutter test
```

---

## Libraries Used

| Package | Version | Purpose |
|---------|---------|---------|
| `camera` | ^0.11.0+2 | Live camera preview and frame capture |
| `google_mlkit_text_recognition` | ^0.13.1 | On-device OCR (Latin script) |
| `image_picker` | ^1.1.2 | Pick images from gallery as an alternative to live camera |
| `permission_handler` | ^11.3.1 | Runtime camera and storage permission requests |
| `google_fonts` | ^6.2.1 | Custom typography (UI polish) |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set |
| `flutter_test` | SDK | Unit and widget testing |
| `flutter_lints` | ^6.0.0 | Static analysis and lint rules |

All parsing logic (Luhn algorithm, IFSC validation, OCR text normalisation) is implemented **manually** — no third-party card or banking library is used.

---

## Assumptions Made

1. **Indian banking context** — IFSC codes follow the RBI pattern (`AAAA0XXXXXX`), where the 5th character is always `0`. Account number length is assumed to be 9–18 digits, consistent with Indian banks.

2. **Latin-script OCR only** — `google_mlkit_text_recognition` is initialised with the Latin script model. Cards or passbooks with text in Devanagari or other scripts will not be read correctly.

3. **Card BIN range 2–6** — The card validator rejects PANs whose first digit falls outside the range 2–6, which covers all current major networks (Visa, Mastercard, RuPay, Amex, Discover). Purely local/proprietary card ranges starting with `1` or `7–9` are treated as invalid.

4. **Portrait-only orientation** — The app locks to portrait mode (`DeviceOrientation.portraitUp`) to simplify the scanner overlay layout. Landscape scanning is not supported.

5. **Single-page passbook scan** — The parser assumes one image or one camera frame captures all required fields (account number, IFSC, holder name). Multi-page passbook spreads are not handled.

6. **Label-driven field extraction** — The passbook parser prioritises explicit labels (`Account Number :`, `IFSC Code :`, `A/c No`, etc.) over positional heuristics. Passbooks with non-standard or heavily abbreviated labels may return partial results.

7. **Multi-capture merging for cards** — The card scanner collects several frames and applies a per-digit majority vote with optional single-digit Luhn repair. This assumes OCR errors are random rather than systematic, which holds for most physical cards but may not hold for worn or heavily embossed card faces.

8. **No backend / no data persistence** — Scan results are shown on-screen only. Nothing is stored to disk or sent to a server.

---

## What Was Skipped and Why

### State Management Library
A dedicated state management package (e.g. Riverpod, Bloc) was not added. Each scanner page uses a lightweight `StatefulWidget`-based controller class. Given the contained scope of this app (two isolated features, no shared global state), introducing a full state management framework would have added boilerplate without benefit.

### Backend / Cloud OCR
Google ML Kit runs entirely on-device. Cloud Vision API or similar services would improve accuracy on low-quality images but would require an API key, internet connectivity, and handling of user data leaving the device — all out of scope for this assignment.

### Card Network Logo Detection
The app does not display Visa/Mastercard/RuPay logos. Detecting the network from BIN ranges requires a BIN lookup database, which was considered out of scope.

### Devanagari / Regional Script Support
ML Kit supports multiple script models, but only the Latin model is bundled. Adding regional script models would increase app size substantially and was beyond the assignment requirements.

### iOS-specific Camera Permissions Entitlement File
A custom `entitlements` file was not created. The `Info.plist` usage description strings are sufficient for App Store review for this project scope.

### Integration / End-to-End Tests
`flutter_driver` or `integration_test` tests were not written. The parsing logic is fully covered by unit tests; UI integration tests would require a physical device with a camera fixture, which is impractical in a CI environment without additional mocking infrastructure.

### Accessibility (a11y)
`Semantics` widgets and screen-reader labels were not added to the scanner overlays. This is a known gap that should be addressed before a production release.

---
