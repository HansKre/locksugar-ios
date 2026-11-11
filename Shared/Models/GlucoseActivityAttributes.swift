#if canImport(ActivityKit) && (os(iOS) || os(visionOS))
import ActivityKit
import Foundation

public struct GlucoseActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var value: Double
        public var valueInMgPerDl: Double
        public var trendArrow: Int?
        public var timestamp: Date
        public var delta: Double?
        public var zone: GlucoseZone
        
        public init(
            value: Double,
            valueInMgPerDl: Double,
            trendArrow: Int? = nil,
            timestamp: Date,
            delta: Double? = nil,
            zone: GlucoseZone = .normal
        ) {
            self.value = value
            self.valueInMgPerDl = valueInMgPerDl
            self.trendArrow = trendArrow
            self.timestamp = timestamp
            self.delta = delta
            self.zone = zone
        }
    }
    
    public var unit: GlucoseUnit
    
    public init(unit: GlucoseUnit = .mgPerDl) {
        self.unit = unit
    }
}
#endif
