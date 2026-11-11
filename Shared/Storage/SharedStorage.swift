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
    }
}
