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

## Running the Automated Test Suite

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
