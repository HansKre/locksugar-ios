import SwiftUI
import WidgetKit

public struct LockSugarCircularView: View {
    @Environment(\.widgetFamily) var family
    public let reading: GlucoseReading?
    public let delta: Double?
    public let useZoneColors: Bool?
    
    public init(reading: GlucoseReading?, delta: Double? = nil, useZoneColors: Bool? = nil) {
        self.reading = reading
        self.delta = delta
        self.useZoneColors = useZoneColors
    }
    
    private var resolvedUseZoneColors: Bool {
        if let explicit = useZoneColors {
            return explicit
        }
        return family != .accessoryCircular
    }
    
    public var body: some View {
        let textColor = resolvedUseZoneColors ? (reading?.zoneColor ?? .primary) : .primary
        ZStack {
            if let reading = reading {
                VStack(spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(reading.formattedValue)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .widgetAccentable(resolvedUseZoneColors)
                        
                        Text(reading.trendArrowSymbol)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .widgetAccentable(resolvedUseZoneColors)
                        
                        if let delta = delta {
                            Text(GlucoseReading.formatDelta(delta))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(textColor)
                                .widgetAccentable(resolvedUseZoneColors)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    
                    HStack(spacing: 3) {
                        Text(reading.glucoseUnits.label)
                        Text("·")
                        Text(reading.formattedTime)
                    }
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                .opacity(reading.isStale() ? 0.5 : 1.0)
            } else {
                Text("---")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .opacity(0.5)
            }
        }
    }
}

public struct LockSugarSmallView: View {
    public let reading: GlucoseReading?
    public let history: [GlucoseReading]
    public let explicitDelta: Double?
    public let targetLow: Double
    public let targetHigh: Double
    
    public init(
        reading: GlucoseReading?,
        history: [GlucoseReading] = [],
        delta: Double? = nil,
        targetLow: Double = GlucoseZone.defaultTargetLow,
        targetHigh: Double = GlucoseZone.defaultTargetHigh
    ) {
        self.reading = reading?.resolvingTrendArrow(with: history)
        self.history = history
        self.explicitDelta = delta
        self.targetLow = targetLow
        self.targetHigh = targetHigh
    }
    
    private var delta: Double? {
        explicitDelta ?? GlucoseReading.calculateDelta(current: reading, history: history)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            
            // Primary Reading + Trend Arrow
            if let reading = reading {
                Text("\(Text(reading.formattedValue).font(.system(size: 44, weight: .bold, design: .rounded)).foregroundColor(.white)) \(Text(reading.trendArrowSymbol).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.95)))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("---")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 6)
            
            // Footer: Timestamp & Delta
            HStack(spacing: 12) {
                if let reading = reading {
                    Text(reading.formattedTime)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("--:--")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Text(GlucoseReading.formatDelta(delta))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .opacity(reading?.isStale() == true ? 0.5 : 1.0)
    }
}
