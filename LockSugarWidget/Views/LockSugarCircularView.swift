import SwiftUI
import WidgetKit

public struct LockSugarCircularView: View {
    public let reading: GlucoseReading?
    
    public init(reading: GlucoseReading?) {
        self.reading = reading
    }
    
    public var body: some View {
        ZStack {
            if let reading = reading {
                VStack(spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(reading.formattedValue)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(reading.zoneColor)
                            .widgetAccentable()
                        
                        Text(reading.trendArrowSymbol)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(reading.zoneColor)
                            .widgetAccentable()
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    
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
    
    public init(reading: GlucoseReading?) {
        self.reading = reading
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Status dot, zone label and timestamp
            HStack {
                if let reading = reading {
                    Circle()
                        .fill(reading.zoneColor)
                        .frame(width: 8, height: 8)
                    Text(reading.zone.label)
                        .font(.caption2.bold())
                        .foregroundColor(reading.zoneColor)
                    Spacer()
                    Text(reading.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("No Data")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            Spacer()
            
            // Value + Trend Arrow
            if let reading = reading {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(reading.formattedValue)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(reading.zoneColor)
                    
                    Text(reading.trendArrowSymbol)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(reading.zoneColor)
                }
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(reading.glucoseUnits.label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    if reading.isStale() {
                        Text("• stale")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                Text("---")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(4)
    }
}
