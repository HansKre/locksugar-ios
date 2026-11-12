import SwiftUI
import WidgetKit

public struct LockSugarInlineView: View {
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
        return family != .accessoryInline
    }
    
    public var body: some View {
        let textColor = resolvedUseZoneColors ? (reading?.zoneColor ?? .primary) : .primary
        if let reading = reading {
            if let delta = delta {
                Text("\(reading.formattedValue) \(reading.trendArrowSymbol) \(GlucoseReading.formatDelta(delta))")
                    .foregroundColor(textColor)
                    .opacity(reading.isStale() ? 0.5 : 1.0)
            } else {
                Text("\(reading.formattedValue) \(reading.trendArrowSymbol)")
                    .foregroundColor(textColor)
                    .opacity(reading.isStale() ? 0.5 : 1.0)
            }
        } else {
            Text("---")
                .opacity(0.5)
        }
    }
}
