import Foundation

public enum GlucoseUnit: Int, Codable {
    case mgPerDl = 0
    case mmolPerL = 1
    
    public var label: String {
        switch self {
        case .mgPerDl:
            return "mg/dL"
        case .mmolPerL:
            return "mmol/L"
        }
    }
}

public struct GlucoseReading: Codable, Equatable {
    public let value: Double
    public let valueInMgPerDl: Double
    public let glucoseUnits: GlucoseUnit
    public let timestamp: Date
    public let trendArrow: Int?
    public let isHigh: Bool
    public let isLow: Bool
    
    public init(
        value: Double,
        valueInMgPerDl: Double,
        glucoseUnits: GlucoseUnit,
        timestamp: Date,
        trendArrow: Int? = nil,
        isHigh: Bool = false,
        isLow: Bool = false
    ) {
        self.value = value
        self.valueInMgPerDl = valueInMgPerDl
        self.glucoseUnits = glucoseUnits
        self.timestamp = timestamp
        self.trendArrow = trendArrow
        self.isHigh = isHigh
        self.isLow = isLow
    }
    
    /// Formatted glucose display text adhering to Lock Screen typography rules:
    /// - Integer values (typically mg/dL): formatted as whole numbers (e.g. "124")
    /// - Decimal values (typically mmol/L): formatted with 1 decimal place (e.g. "6.9")
    public var formattedValue: String {
        switch glucoseUnits {
        case .mgPerDl:
            return "\(Int(round(value)))"
        case .mmolPerL:
            return String(format: "%.1f", value)
        }
    }
    
    /// Checks whether the reading is older than a staleness threshold (default 20 minutes).
    /// Used by Lock Screen widgets to apply a subtle dim opacity (0.5).
    public func isStale(relativeTo referenceDate: Date = Date(), thresholdMinutes: Double = 20.0) -> Bool {
        return referenceDate.timeIntervalSince(timestamp) > (thresholdMinutes * 60)
    }
    
    /// Convenience initializer mapping from raw LibreLinkUp API measurement data.
    public init?(measurement: LLUGlucoseMeasurement) {
        guard let parsedDate = Self.parseTimestamp(measurement.timestamp) else {
            return nil
        }
        
        self.value = measurement.value
        self.valueInMgPerDl = measurement.valueInMgPerDl
        self.glucoseUnits = GlucoseUnit(rawValue: measurement.glucoseUnits) ?? .mgPerDl
        self.timestamp = parsedDate
        self.trendArrow = measurement.trendArrow
        self.isHigh = measurement.isHigh ?? false
        self.isLow = measurement.isLow ?? false
    }
    
    public static func parseTimestamp(_ timestampString: String) -> Date? {
        let trimmed = timestampString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Formatter 1: 12-hour AM/PM e.g. "4/1/2026 10:14:42 AM"
        let formatter12 = DateFormatter()
        formatter12.locale = Locale(identifier: "en_US_POSIX")
        formatter12.dateFormat = "M/d/yyyy h:mm:ss a"
        if let date = formatter12.date(from: trimmed) {
            return date
        }
        
        // Formatter 2: 24-hour e.g. "4/1/2026 10:14:42"
        let formatter24 = DateFormatter()
        formatter24.locale = Locale(identifier: "en_US_POSIX")
        formatter24.dateFormat = "M/d/yyyy HH:mm:ss"
        if let date = formatter24.date(from: trimmed) {
            return date
        }
        
        // Formatter 3: ISO8601 fallback
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }
        
        return nil
    }
    
    /// Default mock reading used for widget gallery preview and placeholders.
    public static var previewMock: GlucoseReading {
        GlucoseReading(
            value: 124,
            valueInMgPerDl: 124,
            glucoseUnits: .mgPerDl,
            timestamp: Date(),
            trendArrow: 3,
            isHigh: false,
            isLow: false
        )
    }
}
