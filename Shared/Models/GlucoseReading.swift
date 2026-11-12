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

/// Time-aware linear regression projection algorithm with exponential weighting and momentum damping.
public enum GlucoseForecastCalculator {
    /// Projection uncertainty configuration:
    /// base: ±2.5 mg/dL baseline sensor uncertainty
    /// ratePerSqrtMinute: ±1.6 mg/dL * sqrt(minutes) diffusion confidence growth
    public static let uncertaintyBase: Double = 2.5
    public static let uncertaintyRatePerSqrtMinute: Double = 1.6
    
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
    
    /// Computes accurate time-aware projection using exponentially weighted linear regression
    /// with momentum damping and a physiologically calibrated confidence funnel.
    public static func calculateProjection(
        from history: [GlucoseReading],
        current: GlucoseReading? = nil,
        minutesAhead: Int = 30
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
        guard let lastReading = allData.last else { return [] }
        
        let dataInterval = calculateDataInterval(from: allData)
        // Use recent data window: at least 30 minutes or 6 data points
        let analysisWindowSeconds = max(30.0 * 60.0, dataInterval * 6.0)
        let analysisStartTime = lastReading.timestamp.addingTimeInterval(-analysisWindowSeconds)
        
        let recentData = allData.filter { $0.timestamp >= analysisStartTime }
        guard recentData.count >= 2 else { return [] }
        
        let lastTimestamp = lastReading.timestamp
        let lastValue = lastReading.valueInMgPerDl
        
        // Exponentially weighted linear regression
        // Half-life tau of 15 minutes gives recent readings proportionally higher influence
        let tau: Double = 15.0
        var sumW: Double = 0.0
        var sumWX: Double = 0.0
        var sumWY: Double = 0.0
        var sumWXX: Double = 0.0
        var sumWXY: Double = 0.0
        
        for item in recentData {
            let minutesAgo = max(0.0, lastTimestamp.timeIntervalSince(item.timestamp) / 60.0)
            let x = -minutesAgo // 0 for last reading, negative for earlier readings
            let y = item.valueInMgPerDl
            let w = exp(-minutesAgo / tau)
            
            sumW += w
            sumWX += w * x
            sumWY += w * y
            sumWXX += w * (x * x)
            sumWXY += w * (x * y)
        }
        
        let denominator = sumW * sumWXX - sumWX * sumWX
        let regressionSlope: Double
        if abs(denominator) > 0.0001 {
            regressionSlope = (sumW * sumWXY - sumWX * sumWY) / denominator
        } else {
            regressionSlope = 0.0
        }
        
        // Blend regression slope with instantaneous velocity between the last two readings if available
        var effectiveSlope = regressionSlope
        if recentData.count >= 2 {
            let prevReading = recentData[recentData.count - 2]
            let dtMinutes = lastTimestamp.timeIntervalSince(prevReading.timestamp) / 60.0
            if dtMinutes >= 1.0 && dtMinutes <= 25.0 {
                let instantVelocity = (lastValue - prevReading.valueInMgPerDl) / dtMinutes
                effectiveSlope = 0.65 * regressionSlope + 0.35 * instantVelocity
            }
        }
        
        // Interval for projection: between 1 and 15 minutes, defaulting to detected interval
        let projectionIntervalSeconds = min(max(dataInterval, 60.0), 15.0 * 60.0)
        let projectionCount = Int(ceil((Double(minutesAhead) * 60.0) / projectionIntervalSeconds))
        
        // Momentum damping coefficient: velocity gracefully decelerates into the future
        let dampingLambda: Double = 0.015
        
        var projections: [GlucoseForecastPoint] = []
        
        for i in 1...max(1, projectionCount) {
            let elapsedSeconds = Double(i) * projectionIntervalSeconds
            let elapsedMinutes = elapsedSeconds / 60.0
            let futureTimestamp = lastTimestamp.addingTimeInterval(elapsedSeconds)
            
            // Damped change: integral of v0 * exp(-lambda * t) = v0 * (1 - exp(-lambda * t)) / lambda
            let dampedDelta: Double
            if dampingLambda > 0.0001 {
                dampedDelta = effectiveSlope * ((1.0 - exp(-dampingLambda * elapsedMinutes)) / dampingLambda)
            } else {
                dampedDelta = effectiveSlope * elapsedMinutes
            }
            
            var projectedValue = lastValue + dampedDelta
            projectedValue = round(max(40.0, min(400.0, projectedValue)))
            
            // Confidence funnel: uncertainty scales with sqrt of elapsed time in minutes
            let uncertainty = uncertaintyBase + uncertaintyRatePerSqrtMinute * sqrt(elapsedMinutes)
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
    
    /// Returns a copy of the reading with a modified trend arrow identifier.
    public func withTrendArrow(_ newTrendArrow: Int?) -> GlucoseReading {
        GlucoseReading(
            value: value,
            valueInMgPerDl: valueInMgPerDl,
            glucoseUnits: glucoseUnits,
            timestamp: timestamp,
            trendArrow: newTrendArrow,
            isHigh: isHigh,
            isLow: isLow
        )
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
    
    /// Calculates trend arrow identifier (1-5) from rate of change in mg/dL per minute matching Abbott's official medical definition:
    /// - Rate > 2.0 mg/dL/min (> +30 in 15m): 5 (↑ Rising quickly)
    /// - Rate 1.0 to 2.0 mg/dL/min (+15 to +30 in 15m): 4 (↗ Rising)
    /// - Rate -1.0 to 1.0 mg/dL/min (-15 to +15 in 15m): 3 (→ Changing slowly / Stable)
    /// - Rate -1.0 to -2.0 mg/dL/min (-15 to -30 in 15m): 2 (↘ Falling)
    /// - Rate < -2.0 mg/dL/min (< -30 in 15m): 1 (↓ Falling quickly)
    public static func calculateTrendArrow(current: GlucoseReading?, previous: GlucoseReading?) -> Int? {
        guard let current = current, let previous = previous else { return nil }
        let timeDeltaMinutes = current.timestamp.timeIntervalSince(previous.timestamp) / 60.0
        // Valid delta interval: between 1 and 35 minutes
        guard timeDeltaMinutes >= 1.0 && timeDeltaMinutes <= 35.0 else { return nil }
        
        let deltaMgPerDl = current.valueInMgPerDl - previous.valueInMgPerDl
        let ratePerMinute = deltaMgPerDl / timeDeltaMinutes
        
        if ratePerMinute > 2.0 {
            return 5
        } else if ratePerMinute >= 1.0 {
            return 4
        } else if ratePerMinute <= -2.0 {
            return 1
        } else if ratePerMinute <= -1.0 {
            return 2
        } else {
            return 3
        }
    }
    
    /// Calculates trend arrow identifier (1-5) for current reading from historical readings if available.
    public static func calculateTrendArrow(current: GlucoseReading?, history: [GlucoseReading]) -> Int? {
        guard let current = current else { return nil }
        let previous = history.filter({ $0.timestamp < current.timestamp }).sorted(by: { $0.timestamp < $1.timestamp }).last
        return calculateTrendArrow(current: current, previous: previous)
    }
    
    /// Returns reading with resolved trend arrow if trendArrow was nil, using historical readings.
    public func resolvingTrendArrow(with history: [GlucoseReading]) -> GlucoseReading {
        if trendArrow != nil { return self }
        if let calculated = Self.calculateTrendArrow(current: self, history: history) {
            return withTrendArrow(calculated)
        }
        return self
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

// MARK: - Trend Arrow Definition

/// Abbott FreeStyle Libre Official Medical Trend Arrow Definitions.
/// Represents rate of change (velocity per minute) and 15-minute projected shift.
public struct TrendArrowDefinition: Identifiable, Equatable {
    public let id: Int // 1 to 5 matching LibreLinkUp trendArrow integer
    public let symbol: String
    public let title: String
    public let rateMgPerDl: String
    public let rateMmolPerL: String
    public let fifteenMinuteChange: String
    public let description: String
    
    public init(
        id: Int,
        symbol: String,
        title: String,
        rateMgPerDl: String,
        rateMmolPerL: String,
        fifteenMinuteChange: String,
        description: String
    ) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.rateMgPerDl = rateMgPerDl
        self.rateMmolPerL = rateMmolPerL
        self.fifteenMinuteChange = fifteenMinuteChange
        self.description = description
    }
    
    public static let allDefinitions: [TrendArrowDefinition] = [
        TrendArrowDefinition(
            id: 5,
            symbol: "↑",
            title: "Rising Quickly",
            rateMgPerDl: "> 2 mg/dL per min",
            rateMmolPerL: "> 0.11 mmol/L per min",
            fifteenMinuteChange: "> +30 mg/dL (> +1.7 mmol/L)",
            description: "Glucose is increasing rapidly. Useful to consider when evaluating meal or insulin timing."
        ),
        TrendArrowDefinition(
            id: 4,
            symbol: "↗",
            title: "Rising",
            rateMgPerDl: "1 – 2 mg/dL per min",
            rateMmolPerL: "0.06 – 0.11 mmol/L per min",
            fifteenMinuteChange: "+15 to +30 mg/dL (+0.8 to +1.7 mmol/L)",
            description: "Glucose is rising moderately. Useful for monitoring post-meal trends."
        ),
        TrendArrowDefinition(
            id: 3,
            symbol: "→",
            title: "Changing Slowly / Stable",
            rateMgPerDl: "< 1 mg/dL per min",
            rateMmolPerL: "< 0.06 mmol/L per min",
            fifteenMinuteChange: "< 15 mg/dL (< 0.8 mmol/L)",
            description: "Glucose is steady or changing slowly. A difference of +5 or -3 mg/dL over a 15-minute gap is only ~0.2 to 0.3 mg/dL/min, which Abbott officially classifies as stable (→)."
        ),
        TrendArrowDefinition(
            id: 2,
            symbol: "↘",
            title: "Falling",
            rateMgPerDl: "1 – 2 mg/dL per min",
            rateMmolPerL: "0.06 – 0.11 mmol/L per min",
            fifteenMinuteChange: "-15 to -30 mg/dL (-0.8 to -1.7 mmol/L)",
            description: "Glucose is decreasing moderately. Helps anticipate reaching target lower boundaries."
        ),
        TrendArrowDefinition(
            id: 1,
            symbol: "↓",
            title: "Falling Quickly",
            rateMgPerDl: "> 2 mg/dL per min",
            rateMmolPerL: "> 0.11 mmol/L per min",
            fifteenMinuteChange: "> -30 mg/dL (> -1.7 mmol/L)",
            description: "Glucose is dropping rapidly. Critical warning indicator to help proactively avoid hypoglycemia."
        )
    ]
    
    public static func definition(for trendArrow: Int?) -> TrendArrowDefinition {
        let targetId = trendArrow ?? 3
        return allDefinitions.first(where: { $0.id == targetId }) ?? allDefinitions[2]
    }
}
