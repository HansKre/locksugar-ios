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
