# LockSugar (`locksugar-ios`)

Ultra-minimalist native iOS application and Lock Screen WidgetKit accessory displaying blood glucose readings directly from LibreLinkUp.

## Overview

- **Main App**: Configuration utility to securely store LibreLinkUp credentials in the device Keychain, test connection, and show Lock Screen widget setup instructions.
- **Lock Screen Widget**: Sits in iOS Lock Screen accessory slots (`accessoryCircular`, `accessoryInline`, `accessoryRectangular`), displaying **only the current glucose number** with zero clutter.

## Project Structure

```
locksugar-ios/
├── LockSugar.xcodeproj               # Xcode project (generated via xcodegen)
├── project.yml                       # XcodeGen project specification
├── Package.swift                     # SPM manifest for core logic & test suite
│
├── Shared/                           # Shared code across App, Widget, and Tests
│   ├── Models/
│   │   ├── GlucoseReading.swift       # Reading, unit formatting, staleness, timeline scheduling
│   │   └── LibreLinkUpResponses.swift # Decodable API response models
│   ├── Storage/
│   │   ├── KeychainHelper.swift       # Shared App Group Keychain wrapper
│   │   └── SharedStorage.swift        # Shared App Group UserDefaults wrapper
│   └── Network/
│       ├── CryptoUtils.swift          # Pure Apple CryptoKit SHA-256 account ID calculation
│       └── LibreLinkUpClient.swift    # Auth, dynamic version negotiation, redirect, graph fetch
│
├── LockSugar/                         # Main App Target
│   ├── LockSugarApp.swift             # App lifecycle & BGAppRefreshTask registration
│   ├── ViewModels/
│   │   └── AppViewModel.swift         # Connection testing & state management
│   ├── Views/
│   │   ├── ContentView.swift          # Credentials form, live reading banner, setup link
│   │   └── WidgetSetupInstructionsView.swift # Step-by-step Lock Screen widget guide
│   ├── Info.plist                     # Background modes & refresh identifiers
│   └── LockSugar.entitlements         # App Groups & Keychain sharing
│
├── LockSugarWidget/                   # Widget Extension Target
│   ├── LockSugarWidget.swift          # Widget configuration & TimelineProvider
│   ├── LockSugarWidgetBundle.swift    # Widget bundle entry point
│   ├── Views/
│   │   ├── LockSugarCircularView.swift    # accessoryCircular
│   │   ├── LockSugarInlineView.swift      # accessoryInline
│   │   └── LockSugarRectangularView.swift # accessoryRectangular
│   ├── Info.plist                     # WidgetKit extension declaration
│   └── LockSugarWidget.entitlements   # App Groups & Keychain sharing
│
└── Tests/                             # Automated Test Suite
    ├── main.swift                     # Test runner
    └── MockURLProtocol.swift          # Mock network session for protocol tests
```

## How to Run Locally

### 1. Prerequisites (Xcode & iOS Simulator)

Because LockSugar is a native iOS App and Lock Screen WidgetKit extension, it requires **Xcode** with the iOS SDK and Simulator:

1. **Install Xcode** from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835) or via `mas`:
   ```bash
   mas install 497799835
   ```
2. **Configure active developer directory**:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. **Accept license & install iOS Simulator platform**:
   ```bash
   sudo xcodebuild -license accept
   xcodebuild -downloadPlatform iOS
   ```

### 2. Open Project in Xcode

The project file `LockSugar.xcodeproj` is generated and tracked in the repository:

```bash
open LockSugar.xcodeproj
```

*(If you ever modify `project.yml`, run `xcodegen generate` to update the Xcode project).*

### 3. Signing & Team Configuration

Because LockSugar uses **App Groups** (`group.com.hanskrebs.locksugar`) and **Keychain Sharing** to allow the Widget Extension and the Main App to communicate:

1. Select the top-level **LockSugar** project in the left navigation sidebar.
2. Under **Targets**, select **LockSugar**:
   - Navigate to the **Signing & Capabilities** tab.
   - Check **Automatically manage signing**.
   - Select your personal Apple ID or Developer **Team**.
3. Under **Targets**, select **LockSugarWidget**:
   - Assign the same **Team** under **Signing & Capabilities**.

### 4. Build & Launch in Simulator

1. In the top toolbar scheme selector, choose **LockSugar** and pick any iOS 16+ Simulator (e.g., **iPhone 15** or **iPhone 16**).
2. Press **`Cmd + R`** (or click the **Play** button).
3. The app will launch:
   - Enter your LibreLinkUp email & password.
   - Tap **"Verify & Connect"** to authenticate and load your live glucose reading.

### 5. Add the Widget to the Lock Screen

1. In the Simulator, lock the screen using **`Cmd + L`** (or swipe down from the top edge to view the Lock Screen).
2. **Long-press** anywhere on the Lock Screen wallpaper until the **Customize** button appears.
3. Tap **Customize** -> choose **Lock Screen**.
4. Tap the accessory slot below or above the clock.
5. In the widget gallery, select **LockSugar** and choose your preferred style:
   - **Inline**: Single line reading above the clock.
   - **Circular**: Large bold rounded number below the clock.
   - **Rectangular**: Centered reading in wide slot.
6. Tap **Done** in the top-right corner.

---

## Running the Automated Test Suite (Without Xcode)

```bash
swift run TestRunner
```

The test suite validates:
1. `CryptoUtils.sha256Hex` (SHA-256 lowercase hex hashing for account ID)
2. `GlucoseReading.unitFormatting` (`mg/dL` integer formatting and `mmol/L` decimal formatting)
3. `GlucoseReading.staleness` (fresh within 20m, dim opacity after 20m)
4. `LibreLinkUpResponses.decodeGraph` (decoding real CGM payload)
5. `KeychainHelper.inMemory` (credentials storage, retrieval, and clearing)
6. `SharedStorage.cacheAndRetrieve` (App Group UserDefaults persistence)
7. `LibreLinkUpClient.minimumVersionRetry` (HTTP 403 minimumVersion bump and automatic retry)
8. `LibreLinkUpClient.regionRedirect` (Regional redirection to `api-{region}.libreview.io`)
9. `LibreLinkUpClient.silentTokenRenewal` (Silent re-login using Keychain credentials)
10. `TimelineScheduler.calculateNextReloadDate` (`measurementTimestamp + 5 min + 15 s` buffer & fallback)

## Regenerating the Xcode Project

```bash
xcodegen generate
```
