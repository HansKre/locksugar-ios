import WidgetKit
import SwiftUI

public struct GlucoseEntry: TimelineEntry {
    public let date: Date
    public let reading: GlucoseReading?
    
    public init(date: Date, reading: GlucoseReading?) {
        self.date = date
        self.reading = reading
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
        GlucoseEntry(date: Date(), reading: .previewMock)
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        if context.isPreview {
            completion(GlucoseEntry(date: Date(), reading: .previewMock))
            return
        }
        let reading = storage.cachedGlucoseReading ?? .previewMock
        completion(GlucoseEntry(date: Date(), reading: reading))
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
            
            let entry = GlucoseEntry(date: Date(), reading: reading)
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
                LockSugarRectangularView(reading: entry.reading)
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
                Color.clear
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
        .description("Ultra-minimalist glucose reading on your Lock Screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}
