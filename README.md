# LockSugar (`locksugar-ios`)

Ultra-minimalist native iOS application and Lock Screen WidgetKit accessory displaying blood glucose readings directly from LibreLinkUp.

## Overview

- **Main App**: Configuration utility to securely store LibreLinkUp credentials in the device Keychain, test connection, and show widget setup instructions for Lock Screen and Apple CarPlay.
- **Widgets**:
  - **Apple CarPlay & Home Screen (`systemSmall`)**: Driver-optimized card displaying glucose value, directional trend arrow, reading time, delta change, and a vertical target range gauge on an adaptive emerald green container background.
  - **Lock Screen Accessories (`accessoryCircular`, `accessoryInline`, `accessoryRectangular`)**: Ultra-glanceable glucose numbers and trend charts directly on your Lock Screen.

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

### 1. Prerequisites (Xcode & iOS SDK)

LockSugar is a native iOS App and Lock Screen WidgetKit extension. Running it locally requires **Xcode**:

1. **Install Xcode** from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835) or via `mas`:
   ```bash
   mas install 497799835
   ```
2. **Configure active developer directory**:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. **Accept license & install iOS platform**:

   ```bash
   sudo xcodebuild -license accept
   xcodebuild -downloadPlatform iOS
   ```

4. **Open the project**:
   ```bash
   open LockSugar.xcodeproj
   ```
   _(If you ever modify `project.yml`, run `xcodegen generate` to update the Xcode project)._

---

### Option A: Run on a Personal iPhone (Free Apple ID — $0)

You **do not need a paid $99/year Apple Developer account** to run LockSugar on your own device. You can use your personal Apple ID as a **Personal Team**:

> **Note on Free Personal Signing (7-Day Expiry)**:
> Apple limits free development provisioning profiles to **7 days**. After 7 days, iOS will state the app is _"No longer available"_. To refresh it, simply reconnect your iPhone to your Mac (via cable or Wi-Fi) and hit **`Cmd + R`** in Xcode again. All your settings and credentials remain intact.

#### 1. Add your Apple ID to Xcode

- In Xcode, go to **Xcode** > **Settings** (or press `Cmd + ,`) > **Accounts**.
- Click **`+`** in the bottom-left and select **Apple ID**.
- Sign in with your standard Apple ID. It will appear as `Your Name (Personal Team)`.

#### 2. Enable Developer Mode on your iPhone (iOS 16+)

- On your iPhone, open **Settings** > **Privacy & Security**.
- Scroll to the bottom, tap **Developer Mode**, and turn it **ON**.
- Restart your iPhone when prompted, then tap **Turn On** and enter your passcode.

#### 3. Connect iPhone & Enable Wi-Fi Sync

- Connect your iPhone to your Mac using a USB cable.
- On your iPhone, tap **Trust This Computer** and enter your passcode.
- In Xcode, go to **Xcode** > **Open Developer Tool** > **Device Hub**.
- Once in Device Hub, select your iPhone from the sidebar. Ensure both your Mac and iPhone are on the same Wi-Fi network.
- Click the **Add Device button (+)** and choose **Pair Nearby Device...** from the pop-up menu.

_(Alternatively, you can access this by clicking the run destination pop-up menu at the top of your workspace (where you currently select your device or simulator next to the Play button) and choosing **Manage Devices...**.)_

#### 4. Configure Signing in Xcode

- In the left sidebar, select the top-level **LockSugar** project.
- Select target **LockSugar**:
  - Go to the **Signing & Capabilities** tab.
  - Check **Automatically manage signing**.
  - Select your `Your Name (Personal Team)` in the **Team** dropdown.
  - If Xcode displays a conflict with the bundle ID, slightly customize the prefix (e.g., `com.<yourname>.locksugar`).
- Select target **LockSugarWidget**:
  - Assign the same `Your Name (Personal Team)` in the **Team** dropdown.
  - Update the bundle identifier to match (e.g., `com.<yourname>.locksugar.widget`).
  - Verify both targets use the same App Group (`group.com.hanskrebs.locksugar` or your customized group).

#### 5. Install to Device

- In Xcode's top destination toolbar, select your **connected iPhone** instead of a Simulator.
- Press **`Cmd + R`** to build and install.

#### 6. Trust the Developer Certificate (First Run Only)

Before iOS allows you to open the app for the first time:

- On your iPhone, open **Settings** > **General** > **VPN & Device Management**.
- Under **Developer App**, tap your Apple ID and tap **Trust "[Your Apple ID]"**.
- You can now launch LockSugar, enter your LibreLinkUp credentials, and add the widget to your Lock Screen!

---

### Option B: Run in the iOS Simulator

1. **Signing**: Under **Signing & Capabilities** for both `LockSugar` and `LockSugarWidget`, select any Team (or your Personal Team).
2. **Select Destination**: In the top toolbar, choose an iOS Simulator (e.g., **iPhone 15** or **iPhone 16**).
3. **Launch**: Press **`Cmd + R`** to run.
4. **Lock Screen Widget**:
   - Press **`Cmd + L`** to lock the simulated device (or swipe down from the top edge).
   - Long-press the Lock Screen background and tap **Customize** > **Lock Screen**.
   - Tap the accessory area and select **LockSugar** (`Inline`, `Circular`, or `Rectangular`).
   - Tap **Done**.

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
