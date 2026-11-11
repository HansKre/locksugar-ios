import WidgetKit
import SwiftUI

public struct GlucoseEntry: TimelineEntry {
    public let date: Date
    public let reading: GlucoseReading?
    public let history: [GlucoseReading]
    public let forecast: [GlucoseForecastPoint]
    public let targetLow: Double
    public let targetHigh: Double
    
    public init(
        date: Date,
        reading: GlucoseReading?,
        history: [GlucoseReading] = [],
        forecast: [GlucoseForecastPoint] = [],
        targetLow: Double = GlucoseZone.defaultTargetLow,
        targetHigh: Double = GlucoseZone.defaultTargetHigh
    ) {
        self.date = date
        self.reading = reading
        self.history = history
        self.forecast = forecast
        self.targetLow = targetLow
        self.targetHigh = targetHigh
    }
}

public struct GlucoseTimelineProvider: TimelineProvider {
    public let client: LibreLinkUpClient
    public let storage: SharedStorage
    
    public init(
        client: LibreLinkUpClient = .shared,
        storage: SharedStorage = .shared
    ) {
        self.client = client
        self.storage = storage
    }
    
    public func placeholder(in context: Context) -> GlucoseEntry {
        let mock = GlucoseReading.previewMock
        let history = GlucoseReading.previewHistory
        let forecast = GlucoseForecastCalculator.calculateProjection(from: history, current: mock)
        return GlucoseEntry(
            date: Date(),
            reading: mock,
            history: history,
            forecast: forecast,
            targetLow: storage.targetLow ?? GlucoseZone.defaultTargetLow,
            targetHigh: storage.targetHigh ?? GlucoseZone.defaultTargetHigh
        )
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let reading = storage.cachedGlucoseReading ?? .previewMock
        let history = storage.cachedGlucoseHistory.isEmpty ? GlucoseReading.previewHistory : storage.cachedGlucoseHistory
        let forecast = GlucoseForecastCalculator.calculateProjection(from: history, current: reading)
        let entry = GlucoseEntry(
            date: Date(),
            reading: reading,
            history: history,
            forecast: forecast,
            targetLow: storage.targetLow ?? GlucoseZone.defaultTargetLow,
            targetHigh: storage.targetHigh ?? GlucoseZone.defaultTargetHigh
        )
        completion(entry)
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        Task {
            var reading: GlucoseReading? = storage.cachedGlucoseReading
            
            do {
                let freshReading = try await client.fetchCurrentReading()
                reading = freshReading
            } catch {
                // If network fetch fails, use cached reading
                reading = storage.cachedGlucoseReading
            }
            
            let history = storage.cachedGlucoseHistory.isEmpty && reading == nil ? GlucoseReading.previewHistory : storage.cachedGlucoseHistory
            let forecast = GlucoseForecastCalculator.calculateProjection(from: history, current: reading)
            let entry = GlucoseEntry(
                date: Date(),
                reading: reading,
                history: history,
                forecast: forecast,
                targetLow: storage.targetLow ?? GlucoseZone.defaultTargetLow,
                targetHigh: storage.targetHigh ?? GlucoseZone.defaultTargetHigh
            )
            let reloadDate = TimelineScheduler.calculateNextReloadDate(for: reading?.timestamp, from: Date())
            
            let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
            completion(timeline)
        }
    }
    
    public static func calculateNextReloadDate(for measurementTimestamp: Date?, from now: Date = Date()) -> Date {
        TimelineScheduler.calculateNextReloadDate(for: measurementTimestamp, from: now)
    }
}

struct LockSugarWidgetEntryView: View {
    var entry: GlucoseTimelineProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                LockSugarCircularView(reading: entry.reading)
            case .accessoryInline:
                LockSugarInlineView(reading: entry.reading)
            case .accessoryRectangular:
                LockSugarRectangularView(
                    reading: entry.reading,
                    history: entry.history,
                    forecast: entry.forecast,
                    targetLow: entry.targetLow,
                    targetHigh: entry.targetHigh
                )
            case .systemSmall:
                LockSugarSmallView(reading: entry.reading)
            case .systemMedium:
                LockSugarMediumView(
                    reading: entry.reading,
                    history: entry.history,
                    forecast: entry.forecast,
                    targetLow: entry.targetLow,
                    targetHigh: entry.targetHigh
                )
            default:
                LockSugarCircularView(reading: entry.reading)
            }
        }
        .applyContainerBackgroundIfAvailable()
    }
}

private extension View {
    @ViewBuilder
    func applyContainerBackgroundIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(UIColor.secondarySystemBackground)
            }
        } else {
            self
        }
    }
}

public struct LockSugarWidget: Widget {
    public static let kind: String = "LockSugarWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlucoseTimelineProvider()) { entry in
            LockSugarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LockSugar")
        .description("Ultra-minimalist glucose reading on your Lock Screen and Home Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .systemSmall,
            .systemMedium
        ])
    }
}
