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
        self.lastReading = storage.cachedGlucoseReading
        self.isConnected = (keychain.get(KeychainHelper.Key.jwtToken) != nil || keychain.get(KeychainHelper.Key.password) != nil) && storage.patientId != nil
    }
    
    public func verifyConnection() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            self.errorMessage = "Please enter both email and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (jwt, accountIdHash) = try await client.login(email: trimmedEmail, password: password)
            let patientId = try await client.getConnections(jwtToken: jwt, accountIdHash: accountIdHash)
            let reading = try await client.getGraph(patientId: patientId, jwtToken: jwt, accountIdHash: accountIdHash)
            
            self.lastReading = reading
            self.isConnected = true
            self.isLoading = false
            
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
            #endif
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    public func disconnect() {
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
