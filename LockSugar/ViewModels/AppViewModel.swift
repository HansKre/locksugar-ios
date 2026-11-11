import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var lastReading: GlucoseReading? = nil
    @Published public var isConnected: Bool = false
    @Published public var showingInstructions: Bool = false
    @Published public var isDynamicYAxisEnabled: Bool = true
    
    public let client: LibreLinkUpClient
    public let keychain: KeychainManaging
    public let storage: SharedStorage
    
    public init(
        client: LibreLinkUpClient = .shared,
        keychain: KeychainManaging = KeychainHelper.shared,
        storage: SharedStorage = .shared
    ) {
        self.client = client
        self.keychain = keychain
        self.storage = storage
        
        // Restore existing configuration
        if let storedEmail = keychain.get(KeychainHelper.Key.email) {
            self.email = storedEmail
        }
        if let storedPassword = keychain.get(KeychainHelper.Key.password) {
            self.password = storedPassword
        }
        self.lastReading = storage.cachedGlucoseReading
        self.isDynamicYAxisEnabled = storage.isDynamicYAxisEnabled
        let hasCredentials = (keychain.get(KeychainHelper.Key.email) != nil && keychain.get(KeychainHelper.Key.password) != nil)
        let hasToken = (keychain.get(KeychainHelper.Key.jwtToken) != nil || keychain.get(KeychainHelper.Key.password) != nil) && storage.patientId != nil
        self.isConnected = hasCredentials || hasToken
    }
    
    public func updateFromStorageIfNewer() {
        if let cached = storage.cachedGlucoseReading {
            if let current = lastReading {
                if cached.timestamp > current.timestamp {
                    self.lastReading = cached
                }
            } else {
                self.lastReading = cached
            }
        }
    }
    
    public func refreshReading() async {
        guard !isLoading else { return }
        guard isConnected else { return }
        
        updateFromStorageIfNewer()
        
        isLoading = true
        errorMessage = nil
        
        do {
            let reading = try await client.fetchCurrentReading()
            self.lastReading = reading
            self.isConnected = true
            self.isLoading = false
            
            LiveActivityManager.shared.updateLiveActivity(reading: reading, history: storage.cachedGlucoseHistory)
            
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
            #endif
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            if case LibreLinkUpError.missingCredentials = error {
                self.isConnected = false
            }
        }
    }
    
    public func verifyConnection() async {
        let inputEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEmail = inputEmail.isEmpty ? (keychain.get(KeychainHelper.Key.email) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) : inputEmail
        let resolvedPassword = password.isEmpty ? (keychain.get(KeychainHelper.Key.password) ?? "") : password
        
        guard !resolvedEmail.isEmpty, !resolvedPassword.isEmpty else {
            self.errorMessage = "Please enter both email and password."
            return
        }
        
        if self.email != resolvedEmail {
            self.email = resolvedEmail
        }
        if self.password != resolvedPassword {
            self.password = resolvedPassword
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (jwt, accountIdHash) = try await client.login(email: resolvedEmail, password: resolvedPassword)
            let patientId = try await client.getConnections(jwtToken: jwt, accountIdHash: accountIdHash)
            let reading = try await client.getGraph(patientId: patientId, jwtToken: jwt, accountIdHash: accountIdHash)
            
            self.lastReading = reading
            self.isConnected = true
            self.isLoading = false
            
            LiveActivityManager.shared.updateLiveActivity(reading: reading, history: storage.cachedGlucoseHistory)
            
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
            #endif
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    public func setDynamicYAxisEnabled(_ enabled: Bool) {
        self.isDynamicYAxisEnabled = enabled
        storage.isDynamicYAxisEnabled = enabled
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
        #endif
    }
    
    public func disconnect() {
        LiveActivityManager.shared.endLiveActivity()
        keychain.clearAll()
        storage.clearAll()
        
        self.email = ""
        self.password = ""
        self.lastReading = nil
        self.isConnected = false
        self.errorMessage = nil
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
        #endif
    }
}
