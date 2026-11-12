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
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
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
    
    // MARK: - Widget Tap & URL Trampoline
    
    private func handleIncomingURL(_ url: URL) {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            // If the URL explicitly requests opening LockSugar, or is not a widget trampoline: stay in LockSugar
            if url.scheme == "locksugar" && (url.host == "open" || url.host != "widget-tap") {
                return
            }
            
            var targetURL: URL?
            
            // 1. If target URL was explicitly encoded as a query item (e.g. locksugar://widget-tap?target=...)
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let targetString = components.queryItems?.first(where: { $0.name == "target" })?.value,
               let parsed = URL(string: targetString) {
                targetURL = parsed
            } else if url.scheme != "locksugar" {
                // 2. If url itself is an external scheme
                targetURL = url
            } else if url.host == "widget-tap" {
                // 3. Fallback only for locksugar://widget-tap with missing query item
                targetURL = SharedStorage.shared.resolvedWidgetURL
            } else {
                // Any other URL remains in LockSugar
                return
            }
            
            guard let destination = targetURL, destination.scheme != "locksugar" else {
                // Destined for LockSugar itself; do nothing and stay in LockSugar
                return
            }
            
            Self.openTargetURL(destination)
        }
        #endif
    }
    
    #if canImport(UIKit)
    private static func openTargetURL(_ destination: URL) {
        UIApplication.shared.open(destination, options: [:]) { success in
            if !success && destination.scheme == "freestylelibre3" {
                // If direct scheme fails, fallback to Apple Shortcut or App Store
                if let shortcutURL = URL(string: SharedStorage.WidgetTapActionOption.libre3Shortcut.rawValue),
                   UIApplication.shared.canOpenURL(shortcutURL) {
                    UIApplication.shared.open(shortcutURL, options: [:], completionHandler: nil)
                } else if let appStoreURL = URL(string: "itms-apps://apps.apple.com/app/id1525101160") {
                    UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
                }
            }
        }
    }
    #endif
    
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
