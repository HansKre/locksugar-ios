import SwiftUI
import WidgetKit

public struct LockSugarInlineView: View {
    public let reading: GlucoseReading?
    public let delta: Double?
    
    public init(reading: GlucoseReading?, delta: Double? = nil) {
        self.reading = reading
        self.delta = delta
    }
    
    public var body: some View {
        if let reading = reading {
            if let delta = delta {
                Text("\(reading.formattedValue) \(reading.trendArrowSymbol) \(GlucoseReading.formatDelta(delta))")
                    .foregroundColor(reading.zoneColor)
                    .opacity(reading.isStale() ? 0.5 : 1.0)
            } else {
                Text("\(reading.formattedValue) \(reading.trendArrowSymbol)")
                    .foregroundColor(reading.zoneColor)
                    .opacity(reading.isStale() ? 0.5 : 1.0)
            }
        } else {
            Text("---")
                .opacity(0.5)
        }
    }
}
