import Foundation

public final class SharedStorage {
    public static let shared = SharedStorage()
    
    public static let appGroupName = "group.com.hanskrebs.locksugar"
    public static let defaultBaseUrl = "https://api.libreview.io"
    public static let defaultMinimumVersion = "4.16.0"
    
    public enum Key {
        public static let accountIdHash = "locksugar_account_id_hash"
        public static let patientId = "locksugar_patient_id"
        public static let apiBaseUrl = "locksugar_api_base_url"
        public static let apiMinimumVersion = "locksugar_api_minimum_version"
        public static let cachedGlucoseReading = "locksugar_cached_glucose_reading"
        public static let cachedGlucoseHistory = "locksugar_cached_glucose_history"
        public static let targetLow = "locksugar_target_low"
        public static let targetHigh = "locksugar_target_high"
        public static let lastSyncTimestamp = "locksugar_last_sync_timestamp"
        public static let dynamicYAxisEnabled = "locksugar_dynamic_yaxis_enabled"
        public static let showHeadphoneBattery = "locksugar_show_headphone_battery"
        public static let headphoneBatteryInfo = "locksugar_headphone_battery_info"
        public static let widgetTapAction = "locksugar_widget_tap_action"
        public static let widgetTapCustomURL = "locksugar_widget_tap_custom_url"
        public static let insulinShortcutName = "locksugar_insulin_shortcut_name"
    }
    
    public let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults? = UserDefaults(suiteName: appGroupName)) {
        self.userDefaults = userDefaults ?? .standard
    }
    
    public var accountIdHash: String? {
        get { userDefaults.string(forKey: Key.accountIdHash) }
        set { userDefaults.set(newValue, forKey: Key.accountIdHash) }
    }
    
    public var patientId: String? {
        get { userDefaults.string(forKey: Key.patientId) }
        set { userDefaults.set(newValue, forKey: Key.patientId) }
    }
    
    public var apiBaseUrl: String {
        get { userDefaults.string(forKey: Key.apiBaseUrl) ?? Self.defaultBaseUrl }
        set { userDefaults.set(newValue, forKey: Key.apiBaseUrl) }
    }
    
    public var apiMinimumVersion: String {
        get { userDefaults.string(forKey: Key.apiMinimumVersion) ?? Self.defaultMinimumVersion }
        set { userDefaults.set(newValue, forKey: Key.apiMinimumVersion) }
    }
    
    public var cachedGlucoseReading: GlucoseReading? {
        get {
            guard let data = userDefaults.data(forKey: Key.cachedGlucoseReading) else { return nil }
            return try? JSONDecoder().decode(GlucoseReading.self, from: data)
        }
        set {
            if let newValue = newValue, let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Key.cachedGlucoseReading)
            } else {
                userDefaults.removeObject(forKey: Key.cachedGlucoseReading)
            }
        }
    }
    
    public var cachedGlucoseHistory: [GlucoseReading] {
        get {
            guard let data = userDefaults.data(forKey: Key.cachedGlucoseHistory) else { return [] }
            return (try? JSONDecoder().decode([GlucoseReading].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Key.cachedGlucoseHistory)
            } else {
                userDefaults.removeObject(forKey: Key.cachedGlucoseHistory)
            }
        }
    }
    
    public var targetLow: Double? {
        get {
            let val = userDefaults.double(forKey: Key.targetLow)
            return val > 0 ? val : nil
        }
        set {
            if let val = newValue {
                userDefaults.set(val, forKey: Key.targetLow)
            } else {
                userDefaults.removeObject(forKey: Key.targetLow)
            }
        }
    }
    
    public var targetHigh: Double? {
        get {
            let val = userDefaults.double(forKey: Key.targetHigh)
            return val > 0 ? val : nil
        }
        set {
            if let val = newValue {
                userDefaults.set(val, forKey: Key.targetHigh)
            } else {
                userDefaults.removeObject(forKey: Key.targetHigh)
            }
        }
    }
    
    public var lastSyncTimestamp: Date? {
        get { userDefaults.object(forKey: Key.lastSyncTimestamp) as? Date }
        set { userDefaults.set(newValue, forKey: Key.lastSyncTimestamp) }
    }
    
    public var isDynamicYAxisEnabled: Bool {
        get {
            if userDefaults.object(forKey: Key.dynamicYAxisEnabled) == nil {
                return true // default to calibrated Y-axis range
            }
            return userDefaults.bool(forKey: Key.dynamicYAxisEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: Key.dynamicYAxisEnabled)
        }
    }
    
    public var showHeadphoneBattery: Bool {
        get {
            if userDefaults.object(forKey: Key.showHeadphoneBattery) == nil {
                return true // default enabled
            }
            return userDefaults.bool(forKey: Key.showHeadphoneBattery)
        }
        set {
            userDefaults.set(newValue, forKey: Key.showHeadphoneBattery)
        }
    }
    
    public var headphoneBatteryInfo: HeadphoneBatteryInfo? {
        get {
            guard let data = userDefaults.data(forKey: Key.headphoneBatteryInfo) else { return nil }
            return try? JSONDecoder().decode(HeadphoneBatteryInfo.self, from: data)
        }
        set {
            if let newValue = newValue, let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: Key.headphoneBatteryInfo)
            } else {
                userDefaults.removeObject(forKey: Key.headphoneBatteryInfo)
            }
        }
    }
    
    public func updateHeadphoneBattery(isConnected: Bool, batteryLevel: Int?, deviceName: String?) {
        if isConnected {
            self.headphoneBatteryInfo = HeadphoneBatteryInfo(
                isConnected: true,
                batteryLevel: batteryLevel,
                deviceName: deviceName,
                updatedAt: Date()
            )
        } else {
            self.headphoneBatteryInfo = HeadphoneBatteryInfo(
                isConnected: false,
                batteryLevel: nil,
                deviceName: nil,
                updatedAt: Date()
            )
        }
    }
    
    // MARK: - Widget Tap Action
    
    public enum WidgetTapActionOption: String, CaseIterable, Identifiable {
        case libre3Direct = "freestylelibre3://"
        case libre3Shortcut = "shortcuts://run-shortcut?name=Libre%203"
        case lockSugar = "locksugar://"
        case custom = "custom"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .libre3Direct:
                return "FreeStyle Libre 3 (Direct Scheme)"
            case .libre3Shortcut:
                return "FreeStyle Libre 3 (Apple Shortcut: Libre 3)"
            case .lockSugar:
                return "LockSugar App"
            case .custom:
                return "Custom URL / Scheme"
            }
        }
    }
    
    public var widgetTapAction: WidgetTapActionOption {
        get {
            guard let raw = userDefaults.string(forKey: Key.widgetTapAction),
                  let option = WidgetTapActionOption(rawValue: raw) else {
                return .libre3Direct
            }
            return option
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Key.widgetTapAction)
        }
    }
    
    public var widgetTapCustomURL: String {
        get {
            userDefaults.string(forKey: Key.widgetTapCustomURL) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: Key.widgetTapCustomURL)
        }
    }
    
    /// Resolves the URL to be triggered when tapping the widget.
    public var resolvedWidgetURL: URL? {
        switch widgetTapAction {
        case .libre3Direct:
            return URL(string: WidgetTapActionOption.libre3Direct.rawValue)
        case .libre3Shortcut:
            return URL(string: WidgetTapActionOption.libre3Shortcut.rawValue)
        case .lockSugar:
            return URL(string: WidgetTapActionOption.lockSugar.rawValue)
        case .custom:
            let trimmed = widgetTapCustomURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: trimmed)
        }
    }
    
    /// URL assigned to WidgetKit `.widgetURL()`: points to `locksugar://widget-tap` with encoded target
    /// to guarantee SpringBoard invokes LockSugar so `.onOpenURL` can trampoline to the configured target.
    public var widgetLaunchURL: URL {
        if widgetTapAction == .lockSugar {
            return URL(string: "locksugar://open")!
        }
        if let target = resolvedWidgetURL?.absoluteString,
           let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "locksugar://widget-tap?target=\(encoded)") {
            return url
        }
        return URL(string: "locksugar://widget-tap")!
    }
    
    // MARK: - Insulin Timer Shortcut
    
    public static let defaultInsulinShortcutName = "Insulin Timer starten"
    
    public var insulinShortcutName: String {
        get {
            userDefaults.string(forKey: Key.insulinShortcutName) ?? Self.defaultInsulinShortcutName
        }
        set {
            userDefaults.set(newValue, forKey: Key.insulinShortcutName)
        }
    }
    
    /// Target URL for running the insulin timer shortcut.
    public var resolvedInsulinTimerURL: URL? {
        let name = insulinShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? Self.defaultInsulinShortcutName : name
        guard let encodedName = finalName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "shortcuts://run-shortcut?name=\(encodedName)")
    }
    
    /// URL assigned to the left half of the Lock Screen rectangular widget.
    /// Uses the `locksugar://widget-tap?target=...` trampoline to ensure SpringBoard forwards to Shortcuts.
    public var insulinTimerLaunchURL: URL {
        if let target = resolvedInsulinTimerURL?.absoluteString,
           let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "locksugar://widget-tap?target=\(encoded)") {
            return url
        }
        return URL(string: "locksugar://widget-tap")!
    }
    
    public func clearAll() {
        userDefaults.removeObject(forKey: Key.accountIdHash)
        userDefaults.removeObject(forKey: Key.patientId)
        userDefaults.removeObject(forKey: Key.apiBaseUrl)
        userDefaults.removeObject(forKey: Key.apiMinimumVersion)
        userDefaults.removeObject(forKey: Key.cachedGlucoseReading)
        userDefaults.removeObject(forKey: Key.cachedGlucoseHistory)
        userDefaults.removeObject(forKey: Key.targetLow)
        userDefaults.removeObject(forKey: Key.targetHigh)
        userDefaults.removeObject(forKey: Key.lastSyncTimestamp)
        userDefaults.removeObject(forKey: Key.dynamicYAxisEnabled)
        userDefaults.removeObject(forKey: Key.headphoneBatteryInfo)
        userDefaults.removeObject(forKey: Key.widgetTapAction)
        userDefaults.removeObject(forKey: Key.widgetTapCustomURL)
        userDefaults.removeObject(forKey: Key.insulinShortcutName)
    }
}
