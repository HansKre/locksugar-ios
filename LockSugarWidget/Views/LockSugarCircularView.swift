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
                Text(reading.formattedValue)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .opacity(reading.isStale() ? 0.5 : 1.0)
            } else {
                Text("---")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .opacity(0.5)
            }
        }
    }
}
