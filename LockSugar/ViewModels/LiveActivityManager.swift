import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()
    
    @Published public private(set) var isLiveActivityActive: Bool = false
    @Published public var errorMessage: String? = nil
    
    #if canImport(ActivityKit)
    private var currentActivity: Activity<GlucoseActivityAttributes>? = nil
    #endif
    
    public init() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            self.currentActivity = Activity<GlucoseActivityAttributes>.activities.first
            self.isLiveActivityActive = (self.currentActivity != nil)
        }
        #endif
    }
    
    public func startLiveActivity(reading: GlucoseReading, history: [GlucoseReading] = []) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        self.errorMessage = nil
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            self.errorMessage = "Live Activities are disabled in iOS Settings. Please enable them in Settings > Apps > LockSugar."
            return
        }
        
        let delta = GlucoseReading.calculateDelta(current: reading, history: history)
        let state = GlucoseActivityAttributes.ContentState(
            value: reading.value,
            valueInMgPerDl: reading.valueInMgPerDl,
            trendArrow: reading.trendArrow,
            timestamp: reading.timestamp,
            delta: delta,
            zone: reading.zone
        )
        let attributes = GlucoseActivityAttributes(unit: reading.glucoseUnits)
        
        // If an activity already exists, update it instead of creating duplicates
        if let existing = currentActivity ?? Activity<GlucoseActivityAttributes>.activities.first {
            Task {
                await existing.update(ActivityContent(state: state, staleDate: reading.timestamp.addingTimeInterval(20 * 60)))
            }
            self.currentActivity = existing
            self.isLiveActivityActive = true
            return
        }
        
        do {
            let activity = try Activity<GlucoseActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: reading.timestamp.addingTimeInterval(20 * 60)),
                pushType: nil
            )
            self.currentActivity = activity
            self.isLiveActivityActive = true
        } catch {
            self.errorMessage = "Failed to start Live Activity: \(error.localizedDescription)"
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
        #endif
    }
    
    public func updateLiveActivity(reading: GlucoseReading, history: [GlucoseReading] = []) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        let targetActivity = currentActivity ?? Activity<GlucoseActivityAttributes>.activities.first
        guard let activity = targetActivity else {
            return
        }
        
        let delta = GlucoseReading.calculateDelta(current: reading, history: history)
        let state = GlucoseActivityAttributes.ContentState(
            value: reading.value,
            valueInMgPerDl: reading.valueInMgPerDl,
            trendArrow: reading.trendArrow,
            timestamp: reading.timestamp,
            delta: delta,
            zone: reading.zone
        )
        
        Task {
            await activity.update(ActivityContent(state: state, staleDate: reading.timestamp.addingTimeInterval(20 * 60)))
        }
        self.currentActivity = activity
        self.isLiveActivityActive = true
        #endif
    }
    
    public func endLiveActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        let targetActivity = currentActivity ?? Activity<GlucoseActivityAttributes>.activities.first
        if let activity = targetActivity {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
        self.isLiveActivityActive = false
        #endif
    }
    
    public func toggleLiveActivity(reading: GlucoseReading?, history: [GlucoseReading] = []) {
        if isLiveActivityActive {
            endLiveActivity()
        } else if let reading = reading {
            startLiveActivity(reading: reading, history: history)
        }
    }
}
