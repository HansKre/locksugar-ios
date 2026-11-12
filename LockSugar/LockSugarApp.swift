import SwiftUI
import BackgroundTasks
#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct LockSugarApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    private static let backgroundTaskIdentifier = "com.hanskrebs.locksugar.refresh"
    
    init() {
        registerBackgroundTask()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Fast-path reload and audio route check when host app becomes active
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
                #endif
                BluetoothBatteryMonitor.shared.checkCurrentAudioRoute()
            case .background:
                Self.scheduleAppRefresh()
            default:
                break
            }
        }
    }
    
    // MARK: - Background Refresh Task Registration
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            Self.handleAppRefresh(task: appRefreshTask)
        }
    }
    
    private static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // Request background execution starting 5 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule BGAppRefreshTask: \(error)")
        }
    }
    
    private static func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule next execution immediately
        scheduleAppRefresh()
        
        let operationTask = Task {
            do {
                _ = try await LibreLinkUpClient.shared.fetchCurrentReading()
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
                #endif
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            operationTask.cancel()
        }
    }
}
