import SwiftUI
import WidgetKit

public struct LockSugarRectangularView: View {
    public let reading: GlucoseReading?
    
    public init(reading: GlucoseReading?) {
        self.reading = reading
    }
    
    public var body: some View {
        ZStack {
            if let reading = reading {
                Text(reading.formattedValue)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .opacity(reading.isStale() ? 0.5 : 1.0)
            } else {
                Text("---")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .opacity(0.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
