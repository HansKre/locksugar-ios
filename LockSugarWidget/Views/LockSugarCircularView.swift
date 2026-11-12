import SwiftUI
import WidgetKit

public struct LockSugarCircularView: View {
    public let reading: GlucoseReading?
    public let delta: Double?
    
    public init(reading: GlucoseReading?, delta: Double? = nil) {
        self.reading = reading
        self.delta = delta
    }
    
    public var body: some View {
        ZStack {
            if let reading = reading {
                VStack(spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(reading.formattedValue)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(reading.zoneColor)
                            .widgetAccentable()
                        
                        Text(reading.trendArrowSymbol)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(reading.zoneColor)
                            .widgetAccentable()
                        
                        if let delta = delta {
                            Text(GlucoseReading.formatDelta(delta))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(reading.zoneColor)
                                .widgetAccentable()
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
        self.reading = reading
        self.history = history
        self.explicitDelta = delta
        self.targetLow = targetLow
        self.targetHigh = targetHigh
    }
    
    private var delta: Double? {
        explicitDelta ?? GlucoseReading.calculateDelta(current: reading, history: history)
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Left main section: Numbers, trend arrow, timestamp, delta
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                
                // Primary Reading + Trend Arrow
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let reading = reading {
                        Text(reading.formattedValue)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        
                        Text(reading.trendArrowSymbol)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                    } else {
                        Text("---")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer(minLength: 6)
                
                // Footer: Timestamp & Delta
                HStack(spacing: 16) {
                    if let reading = reading {
                        Text(reading.formattedTime)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    } else {
                        Text("--:--")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Text(GlucoseReading.formatDelta(delta))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(reading?.isStale() == true ? 0.5 : 1.0)
            
            // Right section: Vertical Target Range Gauge
            verticalRangeGauge
                .frame(width: 14)
                .opacity(reading?.isStale() == true ? 0.5 : 1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Vertical Range Gauge
    
    private var verticalRangeGauge: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let minMg: Double = 40.0
            let maxMg: Double = 250.0
            let currentVal = reading?.valueInMgPerDl ?? 112.0
            
            // Normalized proportion: 0.0 (bottom, 40 mg/dL) to 1.0 (top, 250 mg/dL)
            let clamped = max(minMg, min(maxMg, currentVal))
            let proportion = (clamped - minMg) / (maxMg - minMg)
            
            // Invert because Y coordinates increase downwards: top is 0, bottom is height
            let thumbRadius: CGFloat = 6.0
            let availableTrackHeight = max(0, height - (thumbRadius * 2))
            let yPosition = height - thumbRadius - (CGFloat(proportion) * availableTrackHeight)
            
            ZStack(alignment: .top) {
                // Background Track Capsule
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 4, height: height)
                    .position(x: geo.size.width / 2, y: height / 2)
                
                // Position Indicator Dot (White thumb)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .position(x: geo.size.width / 2, y: yPosition)
            }
        }
    }
}
