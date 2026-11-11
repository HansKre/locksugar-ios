import Foundation
import SwiftUI

// MARK: - Glucose Unit

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

// MARK: - Glucose Zone & Colors

/// Glucose ranges and zones ported from cgm-monitor-chrome-extension (glucoseConfig.ts).
/// All threshold comparisons are made in mg/dL.
public enum GlucoseZone: String, CaseIterable, Codable {
    case veryLow
    case low
    case normal
    case elevated
    case high
    case veryHigh
    
    /// Classifies a glucose value (in mg/dL) into its zone.
    public static func zone(for valueInMgPerDl: Double) -> GlucoseZone {
        if valueInMgPerDl < 70 {
            return .veryLow
        } else if valueInMgPerDl < 100 {
            return .low
        } else if valueInMgPerDl <= 155 {
            return .normal
        } else if valueInMgPerDl <= 189 {
            return .elevated
        } else if valueInMgPerDl < 250 {
            return .high
        } else {
            return .veryHigh
        }
    }
    
    /// Hex color code defined in glucoseConfig.ts:
    /// VERY_LOW: "#8B0000" (Dark Red)
    /// LOW: "#FF9800" (Orange)
    /// NORMAL: "#4CAF50" (Green)
    /// ELEVATED: "#FF9800" (Orange)
    /// HIGH: "#F44336" (Red)
    /// VERY_HIGH: "#8B0000" (Dark Red)
    public var hexColor: String {
        switch self {
        case .veryLow: return "#8B0000"
        case .low: return "#FF9800"
        case .normal: return "#4CAF50"
        case .elevated: return "#FF9800"
        case .high: return "#F44336"
        case .veryHigh: return "#8B0000"
        }
    }
    
    public var label: String {
        switch self {
        case .veryLow: return "VERY LOW"
        case .low: return "LOW"
        case .normal: return "NORMAL"
        case .elevated: return "ELEVATED"
        case .high: return "HIGH"
        case .veryHigh: return "VERY HIGH"
        }
    }
    
    /// Standard target range constants (in mg/dL) from ReferenceElements.tsx
    public static let defaultTargetLow: Double = 70.0
    public static let defaultTargetHigh: Double = 180.0
}

public extension Color {
    static let glucoseVeryLow = Color(red: 139 / 255.0, green: 0 / 255.0, blue: 0 / 255.0)
    static let glucoseLow = Color(red: 255 / 255.0, green: 152 / 255.0, blue: 0 / 255.0)
    static let glucoseNormal = Color(red: 76 / 255.0, green: 175 / 255.0, blue: 80 / 255.0)
    static let glucoseElevated = Color(red: 255 / 255.0, green: 152 / 255.0, blue: 0 / 255.0)
    static let glucoseHigh = Color(red: 244 / 255.0, green: 67 / 255.0, blue: 54 / 255.0)
    static let glucoseVeryHigh = Color(red: 139 / 255.0, green: 0 / 255.0, blue: 0 / 255.0)
    
    static func forGlucoseZone(_ zone: GlucoseZone) -> Color {
        switch zone {
        case .veryLow: return .glucoseVeryLow
        case .low: return .glucoseLow
        case .normal: return .glucoseNormal
        case .elevated: return .glucoseElevated
        case .high: return .glucoseHigh
        case .veryHigh: return .glucoseVeryHigh
        }
    }
    
    /// Dark semantic container background colors tuned for CarPlay and widget cards.
    static func containerBackground(for zone: GlucoseZone) -> Color {
        switch zone {
        case .normal:
            // Emerald forest green from CarPlay screenshot
            return Color(red: 28 / 255.0, green: 62 / 255.0, blue: 37 / 255.0)
        case .veryLow:
            return Color(red: 80 / 255.0, green: 15 / 255.0, blue: 15 / 255.0)
        case .low:
            return Color(red: 90 / 255.0, green: 45 / 255.0, blue: 12 / 255.0)
        case .elevated:
            return Color(red: 90 / 255.0, green: 45 / 255.0, blue: 12 / 255.0)
        case .high:
            return Color(red: 95 / 255.0, green: 25 / 255.0, blue: 20 / 255.0)
        case .veryHigh:
            return Color(red: 80 / 255.0, green: 15 / 255.0, blue: 15 / 255.0)
        }
    }
}

// MARK: - Forecast Models & Calculator

/// A single projected future glucose value with an uncertainty boundary.
public struct GlucoseForecastPoint: Equatable, Identifiable {
    public var id: Date { timestamp }
    public let timestamp: Date
    public let value: Double
    public let lowerBound: Double
    public let upperBound: Double
    
    public init(timestamp: Date, value: Double, lowerBound: Double, upperBound: Double) {
        self.timestamp = timestamp
        self.value = value
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

/// Time-aware linear regression projection algorithm ported from cgm-monitor-chrome-extension.
public enum GlucoseForecastCalculator {
    /// Projection uncertainty configuration from glucoseConfig.ts:
    /// base: ±5 mg/dL at first projection step
    /// stepPerInterval: +3 mg/dL per additional 5-min interval
    public static let uncertaintyBase: Double = 5.0
    public static let uncertaintyStepPerInterval: Double = 3.0
    
    /// Calculates median interval (in seconds) between consecutive historical data points.
    public static func calculateDataInterval(from readings: [GlucoseReading]) -> TimeInterval {
        guard readings.count >= 2 else { return 5 * 60 }
        
        var intervals: [TimeInterval] = []
        for i in 1..<readings.count {
            let diff = readings[i].timestamp.timeIntervalSince(readings[i - 1].timestamp)
            if diff > 0 {
                intervals.append(diff)
            }
        }
        
        guard !intervals.isEmpty else { return 5 * 60 }
        intervals.sort()
        let midIndex = intervals.count / 2
        return intervals.count % 2 == 0
            ? (intervals[midIndex - 1] + intervals[midIndex]) / 2.0
            : intervals[midIndex]
    }
    
    /// Computes time-aware linear regression projection matching calculateTimeAwareProjection in glucoseUtils.ts.
    public static func calculateProjection(
        from history: [GlucoseReading],
        current: GlucoseReading? = nil,
        minutesAhead: Int = 45
    ) -> [GlucoseForecastPoint] {
        var allData = history.sorted(by: { $0.timestamp < $1.timestamp })
        
        // Merge current reading if present and newer than last history item
        if let current = current {
            if let last = allData.last {
                if current.timestamp > last.timestamp {
                    allData.append(current)
                }
            } else {
                allData.append(current)
            }
        }
        
        guard allData.count >= 3 else { return [] }
        
        let dataInterval = calculateDataInterval(from: allData)
        // Use recent data window: at least 30 minutes or 6 data points
        let analysisWindowSeconds = max(30.0 * 60.0, dataInterval * 6.0)
        guard let lastReading = allData.last else { return [] }
        let analysisStartTime = lastReading.timestamp.addingTimeInterval(-analysisWindowSeconds)
        
        let recentData = allData.filter { $0.timestamp >= analysisStartTime }
        guard recentData.count >= 2 else { return [] }
        
        // Time-based linear regression
        let baseTime = recentData[0].timestamp
        let points: [(x: Double, y: Double)] = recentData.map {
            let minutesFromBase = $0.timestamp.timeIntervalSince(baseTime) / 60.0
            return (x: minutesFromBase, y: $0.valueInMgPerDl)
        }
        
        let n = Double(points.count)
        let sumX = points.reduce(0.0) { $0 + $1.x }
        let sumY = points.reduce(0.0) { $0 + $1.y }
        let sumXY = points.reduce(0.0) { $0 + ($1.x * $1.y) }
        let sumXX = points.reduce(0.0) { $0 + ($1.x * $1.x) }
        
        let denominator = (n * sumXX - sumX * sumX)
        guard abs(denominator) > 0.0001 else { return [] }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        
        // Interval for projection: between 1 and 15 minutes, defaulting to detected interval
        let projectionIntervalSeconds = min(max(dataInterval, 60.0), 15.0 * 60.0)
        let projectionCount = Int(ceil((Double(minutesAhead) * 60.0) / projectionIntervalSeconds))
        
        var projections: [GlucoseForecastPoint] = []
        let lastTimestamp = lastReading.timestamp
        
        for i in 1...max(1, projectionCount) {
            let futureTimestamp = lastTimestamp.addingTimeInterval(Double(i) * projectionIntervalSeconds)
            let futureMinutes = futureTimestamp.timeIntervalSince(baseTime) / 60.0
            var projectedValue = slope * futureMinutes + intercept
            
            // Bounds clamping (0 to 400 mg/dL) and rounding
            projectedValue = round(max(0.0, min(400.0, projectedValue)))
            
            let uncertainty = uncertaintyBase + uncertaintyStepPerInterval * Double(i - 1)
            let lower = max(0.0, projectedValue - uncertainty)
            let upper = min(400.0, projectedValue + uncertainty)
            
            projections.append(GlucoseForecastPoint(
                timestamp: futureTimestamp,
                value: projectedValue,
                lowerBound: lower,
                upperBound: upper
            ))
        }
        
        return projections
    }
}

// MARK: - Glucose Reading

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
    
    /// Formatted glucose display text:
    /// Always formatted as a rounded integer without float/decimal part across all widgets and screens.
    public var formattedValue: String {
        "\(Int(round(value)))"
    }
    
    /// Trend arrow symbol based on LibreLinkUp API definitions (1-5):
    /// 1: ↓ (falling fast)
    /// 2: ↘ (falling)
    /// 3: → (stable)
    /// 4: ↗ (rising)
    /// 5: ↑ (rising fast)
    public var trendArrowSymbol: String {
        Self.arrowSymbol(for: trendArrow)
    }
    
    public static func arrowSymbol(for trendArrow: Int?) -> String {
        switch trendArrow {
        case 1: return "↓"
        case 2: return "↘"
        case 3: return "→"
        case 4: return "↗"
        case 5: return "↑"
        default: return "→"
        }
    }
    
    public var zone: GlucoseZone {
        GlucoseZone.zone(for: valueInMgPerDl)
    }
    
    public var zoneColor: Color {
        Color.forGlucoseZone(zone)
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
    
    /// Calculates the delta between the current reading and the immediately preceding historical reading.
    public static func calculateDelta(current: GlucoseReading?, history: [GlucoseReading]) -> Double? {
        guard let current = current else { return nil }
        if let previous = history.filter({ $0.timestamp < current.timestamp }).last {
            return current.value - previous.value
        }
        return nil
    }
    
    /// Formats the signed delta value (e.g. "+5", "-2", "0", or "--" if unavailable).
    public static func formatDelta(_ delta: Double?) -> String {
        guard let delta = delta else { return "--" }
        let rounded = Int(round(delta))
        if rounded > 0 {
            return "+\(rounded)"
        } else {
            return "\(rounded)"
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
            value: 112,
            valueInMgPerDl: 112,
            glucoseUnits: .mgPerDl,
            timestamp: Date(),
            trendArrow: 3,
            isHigh: false,
            isLow: false
        )
    }
    
    /// Realistic 3-hour history mock for widget preview matching the screenshot.
    public static var previewHistory: [GlucoseReading] {
        let now = Date()
        let values: [Double] = [135, 130, 128, 125, 122, 120, 124, 122, 118, 115, 114, 112]
        return values.enumerated().map { index, val in
            let minutesAgo = Double((values.count - 1 - index) * 15)
            return GlucoseReading(
                value: val,
                valueInMgPerDl: val,
                glucoseUnits: .mgPerDl,
                timestamp: now.addingTimeInterval(-minutesAgo * 60),
                trendArrow: index == values.count - 1 ? 3 : nil
            )
        }
    }
}

// MARK: - Timeline Scheduler

public enum TimelineScheduler {
    /// Intelligent timeline reload calculation:
    /// measurementTimestamp + 5 minutes + 15 seconds buffer.
    /// Fallback to now + 5 minutes when timestamp is unavailable or past.
    public static func calculateNextReloadDate(for measurementTimestamp: Date?, from now: Date = Date()) -> Date {
        guard let timestamp = measurementTimestamp else {
            return now.addingTimeInterval(5 * 60)
        }
        
        let targetReload = timestamp.addingTimeInterval(5 * 60 + 15) // + 5m 15s
        // If target reload date is already in the past or less than 30s away, schedule for 5m from now
        if targetReload <= now.addingTimeInterval(30) {
            return now.addingTimeInterval(5 * 60)
        }
        
        return targetReload
    }
}
