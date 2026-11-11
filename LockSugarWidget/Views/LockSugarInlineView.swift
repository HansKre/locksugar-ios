import SwiftUI
import WidgetKit

public struct LockSugarInlineView: View {
    public let reading: GlucoseReading?
    
    public init(reading: GlucoseReading?) {
        self.reading = reading
    }
    
    public var body: some View {
        if let reading = reading {
            Text("\(reading.formattedValue) \(reading.trendArrowSymbol)")
                .foregroundColor(reading.zoneColor)
                .opacity(reading.isStale() ? 0.5 : 1.0)
        } else {
            Text("---")
                .opacity(0.5)
        }
    }
}
