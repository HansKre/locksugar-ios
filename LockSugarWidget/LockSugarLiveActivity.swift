#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

public struct LockSugarLiveActivity: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlucoseActivityAttributes.self) { context in
            // Lock Screen Banner & CarPlay Dashboard Card Presentation
            let reading = GlucoseReading(
                value: context.state.value,
                valueInMgPerDl: context.state.valueInMgPerDl,
                glucoseUnits: context.attributes.unit,
                timestamp: context.state.timestamp,
                trendArrow: context.state.trendArrow
            )
            
            LockSugarSmallView(
                reading: reading,
                history: [],
                delta: context.state.delta
            )
            .padding(.horizontal, 4)
            .activityBackgroundTint(Color.containerBackground(for: context.state.zone))
        } dynamicIsland: { context in
            let intVal = Int(round(context.state.value))
            let arrow = context.state.trendArrow != nil ? (GlucoseReading(value: context.state.value, valueInMgPerDl: context.state.valueInMgPerDl, glucoseUnits: context.attributes.unit, timestamp: context.state.timestamp, trendArrow: context.state.trendArrow).trendArrowSymbol) : "→"
            let zoneColor = Color.forGlucoseZone(context.state.zone)
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Text("\(intVal)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(zoneColor)
                        Text(arrow)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(zoneColor)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.zone.label)
                            .font(.caption.bold())
                            .foregroundColor(zoneColor)
                        if let delta = context.state.delta {
                            Text(GlucoseReading.formatDelta(delta))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("LibreLinkUp")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(context.state.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Text("\(intVal)")
                    .font(.subheadline.bold())
                    .foregroundColor(zoneColor)
            } compactTrailing: {
                Text(arrow)
                    .font(.subheadline.bold())
                    .foregroundColor(zoneColor)
            } minimal: {
                Text("\(intVal)")
                    .font(.caption.bold())
                    .foregroundColor(zoneColor)
            }
        }
        .supplementalActivityFamiliesIfAvailable()
    }
}

private extension WidgetConfiguration {
    func supplementalActivityFamiliesIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 18.0, *) {
            return self.supplementalActivityFamilies([.small])
        } else {
            return self
        }
    }
}
#endif
