import WidgetKit
import SwiftUI

public struct GlucoseEntry: TimelineEntry {
    public let date: Date
    public let reading: GlucoseReading?
    public let history: [GlucoseReading]
    public let explicitDelta: Double?
    public let forecast: [GlucoseForecastPoint]
    public let targetLow: Double
    public let targetHigh: Double
    public let isDynamicYAxisEnabled: Bool
    public let headphoneInfo: HeadphoneBatteryInfo?
    public let showHeadphoneBattery: Bool
    public let widgetURL: URL?
    
    public var delta: Double? {
        explicitDelta ?? GlucoseReading.calculateDelta(current: reading, history: history)
    }
    
    public init(
        date: Date,
        reading: GlucoseReading?,
        history: [GlucoseReading] = [],
        delta: Double? = nil,
        forecast: [GlucoseForecastPoint] = [],
        targetLow: Double = GlucoseZone.defaultTargetLow,
        targetHigh: Double = GlucoseZone.defaultTargetHigh,
        isDynamicYAxisEnabled: Bool = true,
        headphoneInfo: HeadphoneBatteryInfo? = nil,
        showHeadphoneBattery: Bool = true,
        widgetURL: URL? = nil
    ) {
        self.date = date
        self.reading = reading
        self.history = history
        self.explicitDelta = delta
        self.forecast = forecast
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.isDynamicYAxisEnabled = isDynamicYAxisEnabled
        self.headphoneInfo = headphoneInfo
        self.showHeadphoneBattery = showHeadphoneBattery
        self.widgetURL = widgetURL
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
        let forecast = GlucoseForecastCalculator.calculateProjection(from: history, current: mock, minutesAhead: 30)
        return GlucoseEntry(
            date: Date(),
            reading: mock,
            history: history,
            forecast: forecast,
            targetLow: storage.targetLow ?? GlucoseZone.defaultTargetLow,
            targetHigh: storage.targetHigh ?? GlucoseZone.defaultTargetHigh,
            isDynamicYAxisEnabled: storage.isDynamicYAxisEnabled,
            headphoneInfo: HeadphoneBatteryInfo(isConnected: true, batteryLevel: 85, deviceName: "AirPods Pro"),
            showHeadphoneBattery: storage.showHeadphoneBattery,
            widgetURL: storage.widgetLaunchURL
        )
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let rawReading = storage.cachedGlucoseReading ?? .previewMock
        let history = storage.cachedGlucoseHistory.isEmpty ? GlucoseReading.previewHistory : storage.cachedGlucoseHistory
        let reading = rawReading.resolvingTrendArrow(with: history)
        let forecast = GlucoseForecastCalculator.calculateProjection(from: history, current: reading, minutesAhead: 30)
        let entry = GlucoseEntry(
            date: Date(),
            reading: reading,
            history: history,
            forecast: forecast,
            targetLow: storage.targetLow ?? GlucoseZone.defaultTargetLow,
            targetHigh: storage.targetHigh ?? GlucoseZone.defaultTargetHigh,
            isDynamicYAxisEnabled: storage.isDynamicYAxisEnabled,
            headphoneInfo: storage.headphoneBatteryInfo,
            showHeadphoneBattery: storage.showHeadphoneBattery,
            widgetURL: storage.widgetLaunchURL
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
            let resolvedReading = reading?.resolvingTrendArrow(with: history)
            let forecast = GlucoseForecastCalculator.calculateProjection(from: history, current: resolvedReading, minutesAhead: 30)
            let entry = GlucoseEntry(
                date: Date(),
                reading: resolvedReading,
                history: history,
                forecast: forecast,
                targetLow: storage.targetLow ?? GlucoseZone.defaultTargetLow,
                targetHigh: storage.targetHigh ?? GlucoseZone.defaultTargetHigh,
                isDynamicYAxisEnabled: storage.isDynamicYAxisEnabled,
                headphoneInfo: storage.headphoneBatteryInfo,
                showHeadphoneBattery: storage.showHeadphoneBattery,
                widgetURL: storage.widgetLaunchURL
            )
            let reloadDate = TimelineScheduler.calculateNextReloadDate(for: resolvedReading?.timestamp, from: Date())
            
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
    
    private var targetWidgetURL: URL? {
        switch family {
        case .systemMedium, .systemSmall:
            return nil
        case .accessoryCircular, .accessoryInline, .accessoryRectangular:
            return entry.widgetURL
        default:
            return entry.widgetURL
        }
    }
    
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                LockSugarCircularView(reading: entry.reading, delta: entry.delta)
            case .accessoryInline:
                LockSugarInlineView(reading: entry.reading, delta: entry.delta)
            case .accessoryRectangular:
                LockSugarRectangularView(
                    reading: entry.reading,
                    history: entry.history,
                    delta: entry.delta,
                    forecast: entry.forecast,
                    targetLow: entry.targetLow,
                    targetHigh: entry.targetHigh,
                    isDynamicYAxisEnabled: entry.isDynamicYAxisEnabled,
                    headphoneInfo: entry.headphoneInfo,
                    showHeadphoneBattery: entry.showHeadphoneBattery
                )
            case .systemSmall:
                LockSugarSmallView(
                    reading: entry.reading,
                    history: entry.history,
                    delta: entry.delta,
                    targetLow: entry.targetLow,
                    targetHigh: entry.targetHigh
                )
            case .systemMedium:
                LockSugarMediumView(
                    reading: entry.reading,
                    history: entry.history,
                    delta: entry.delta,
                    forecast: entry.forecast,
                    targetLow: entry.targetLow,
                    targetHigh: entry.targetHigh,
                    isDynamicYAxisEnabled: entry.isDynamicYAxisEnabled,
                    headphoneInfo: entry.headphoneInfo,
                    showHeadphoneBattery: entry.showHeadphoneBattery
                )
            default:
                LockSugarCircularView(reading: entry.reading, delta: entry.delta)
            }
        }
        .applyContainerBackgroundIfAvailable(family: family, reading: entry.reading)
        .widgetURL(targetWidgetURL)
    }
}

private extension View {
    @ViewBuilder
    func applyContainerBackgroundIfAvailable(family: WidgetFamily, reading: GlucoseReading?) -> some View {
        if #available(iOS 17.0, *) {
            switch family {
            case .accessoryCircular, .accessoryInline, .accessoryRectangular:
                self.containerBackground(for: .widget) {
                    Color.clear
                }
            case .systemSmall:
                self.containerBackground(for: .widget) {
                    Color.containerBackground(for: reading?.zone ?? .normal)
                }
            case .systemMedium:
                self.containerBackground(for: .widget) {
                    Color(UIColor.secondarySystemBackground)
                }
            default:
                self.containerBackground(for: .widget) {
                    Color(UIColor.secondarySystemBackground)
                }
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
