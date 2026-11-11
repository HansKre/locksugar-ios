import Foundation

public enum LibreLinkUpError: LocalizedError {
    case missingCredentials
    case invalidResponse(statusCode: Int, message: String?)
    case minimumVersionMismatch(requiredVersion: String)
    case authenticationFailed(String)
    case noPatientFound
    case noMeasurementData
    case invalidUrl
    
    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "No credentials stored. Please configure in LockSugar app."
        case .invalidResponse(let code, let message):
            return "Server responded with code \(code): \(message ?? "Unknown error")"
        case .minimumVersionMismatch(let ver):
            return "API requires minimum version \(ver)."
        case .authenticationFailed(let msg):
            return "Authentication failed: \(msg)"
        case .noPatientFound:
            return "No patient connection found for this account."
        case .noMeasurementData:
            return "No recent glucose measurement available."
        case .invalidUrl:
            return "Invalid API URL."
        }
    }
}

public final class LibreLinkUpClient {
    public static let shared = LibreLinkUpClient()
    
    public let session: URLSession
    public let keychain: KeychainManaging
    public let storage: SharedStorage
    
    public init(
        session: URLSession = .shared,
        keychain: KeychainManaging = KeychainHelper.shared,
        storage: SharedStorage = .shared
    ) {
        self.session = session
        self.keychain = keychain
        self.storage = storage
    }
    
    // MARK: - Headers Helper
    
    private func buildHeaders(jwtToken: String? = nil, accountIdHash: String? = nil) -> [String: String] {
        var headers: [String: String] = [
            "product": "llu.android",
            "version": storage.apiMinimumVersion,
            "accept-encoding": "gzip",
            "cache-control": "no-cache",
            "connection": "Keep-Alive",
            "content-type": "application/json"
        ]
        
        if let jwtToken = jwtToken {
            headers["authorization"] = "Bearer \(jwtToken)"
        }
        
        if let accountIdHash = accountIdHash {
            headers["account-id"] = accountIdHash
        }
        
        return headers
    }
    
    // MARK: - Login & Authentication
    
    public func login(
        email: String,
        password: String,
        isRetryAfterVersionUpdate: Bool = false
    ) async throws -> (jwtToken: String, accountIdHash: String) {
        guard let url = URL(string: "\(storage.apiBaseUrl)/llu/auth/login") else {
            throw LibreLinkUpError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = buildHeaders()
        
        let bodyPayload = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LibreLinkUpError.invalidResponse(statusCode: -1, message: "Non-HTTP response")
        }
        
        // 1. Check for 403 minimumVersion requirement
        if httpResponse.statusCode == 403 {
            if let errorResponse = try? JSONDecoder().decode(LLUErrorResponse.self, from: data),
               let minVer = errorResponse.data?.minimumVersion ?? (try? JSONDecoder().decode(LLULoginResponse.self, from: data))?.data?.minimumVersion {
                storage.apiMinimumVersion = minVer
                if !isRetryAfterVersionUpdate {
                    return try await login(email: email, password: password, isRetryAfterVersionUpdate: true)
                }
                throw LibreLinkUpError.minimumVersionMismatch(requiredVersion: minVer)
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = (try? JSONDecoder().decode(LLUErrorResponse.self, from: data))?.error?.message
            throw LibreLinkUpError.invalidResponse(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        let loginResponse = try JSONDecoder().decode(LLULoginResponse.self, from: data)
        
        // 2. Check for region redirect
        if loginResponse.data?.redirect == true, let region = loginResponse.data?.region {
            let redirectedBaseUrl = "https://api-\(region).libreview.io"
            storage.apiBaseUrl = redirectedBaseUrl
            return try await login(email: email, password: password, isRetryAfterVersionUpdate: isRetryAfterVersionUpdate)
        }
        
        guard let jwtToken = loginResponse.data?.authTicket?.token,
              let userId = loginResponse.data?.user?.id else {
            let message = loginResponse.error?.message ?? "Missing authTicket or user ID in response"
            throw LibreLinkUpError.authenticationFailed(message)
        }
        
        let accountIdHash = CryptoUtils.sha256Hex(userId)
        
        // Persist credentials & tokens
        keychain.set(email, forKey: KeychainHelper.Key.email)
        keychain.set(password, forKey: KeychainHelper.Key.password)
        keychain.set(jwtToken, forKey: KeychainHelper.Key.jwtToken)
        storage.accountIdHash = accountIdHash
        
        return (jwtToken, accountIdHash)
    }
    
    // MARK: - Patient Connections
    
    public func getConnections(
        jwtToken: String,
        accountIdHash: String,
        isRetryAfterVersionUpdate: Bool = false
    ) async throws -> String {
        guard let url = URL(string: "\(storage.apiBaseUrl)/llu/connections") else {
            throw LibreLinkUpError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = buildHeaders(jwtToken: jwtToken, accountIdHash: accountIdHash)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LibreLinkUpError.invalidResponse(statusCode: -1, message: "Non-HTTP response")
        }
        
        if httpResponse.statusCode == 403 {
            if let errorResponse = try? JSONDecoder().decode(LLUErrorResponse.self, from: data),
               let minVer = errorResponse.data?.minimumVersion {
                storage.apiMinimumVersion = minVer
                if !isRetryAfterVersionUpdate {
                    return try await getConnections(jwtToken: jwtToken, accountIdHash: accountIdHash, isRetryAfterVersionUpdate: true)
                }
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = (try? JSONDecoder().decode(LLUErrorResponse.self, from: data))?.error?.message
            throw LibreLinkUpError.invalidResponse(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        let connectionsResponse = try JSONDecoder().decode(LLUConnectionsResponse.self, from: data)
        guard let patientId = connectionsResponse.data?.first?.patientId else {
            throw LibreLinkUpError.noPatientFound
        }
        
        storage.patientId = patientId
        return patientId
    }
    
    // MARK: - Graph & Glucose Data
    
    public func getGraph(
        patientId: String,
        jwtToken: String,
        accountIdHash: String,
        isRetryAfterVersionUpdate: Bool = false
    ) async throws -> GlucoseReading {
        guard let url = URL(string: "\(storage.apiBaseUrl)/llu/connections/\(patientId)/graph") else {
            throw LibreLinkUpError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = buildHeaders(jwtToken: jwtToken, accountIdHash: accountIdHash)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LibreLinkUpError.invalidResponse(statusCode: -1, message: "Non-HTTP response")
        }
        
        // Check for 403 minimumVersion
        if httpResponse.statusCode == 403 {
            if let errorResponse = try? JSONDecoder().decode(LLUErrorResponse.self, from: data),
               let minVer = errorResponse.data?.minimumVersion {
                storage.apiMinimumVersion = minVer
                if !isRetryAfterVersionUpdate {
                    return try await getGraph(patientId: patientId, jwtToken: jwtToken, accountIdHash: accountIdHash, isRetryAfterVersionUpdate: true)
                }
            }
        }
        
        // If 401 or 403 without version mismatch, caller will re-authenticate
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = (try? JSONDecoder().decode(LLUErrorResponse.self, from: data))?.error?.message
            throw LibreLinkUpError.invalidResponse(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        let graphResponse = try JSONDecoder().decode(LLUGraphResponse.self, from: data)
        
        var chosenReading: GlucoseReading?
        if let latestMeasurement = graphResponse.data?.connection?.glucoseMeasurement ?? graphResponse.data?.connection?.glucoseItem,
           let reading = GlucoseReading(measurement: latestMeasurement) {
            chosenReading = reading
        }
        
        // If graphData contains a strictly newer measurement, or if glucoseMeasurement was nil/failed to parse:
        if let graphData = graphResponse.data?.graphData {
            let parsedGraph = graphData.compactMap { GlucoseReading(measurement: $0) }
            if let newestGraphReading = parsedGraph.max(by: { $0.timestamp < $1.timestamp }) {
                if let current = chosenReading {
                    if newestGraphReading.timestamp > current.timestamp {
                        chosenReading = newestGraphReading
                    }
                } else {
                    chosenReading = newestGraphReading
                }
            }
        }
        
        guard let reading = chosenReading else {
            throw LibreLinkUpError.noMeasurementData
        }
        
        // Cache latest reading
        storage.cachedGlucoseReading = reading
        storage.lastSyncTimestamp = Date()
        
        return reading
    }
    
    // MARK: - High-level Fetch with Silent Re-Auth
    
    /// Fetches the latest glucose reading. Automatically handles silent re-authentication
    /// using stored Keychain credentials if JWT is missing, expired, or rejected.
    public func fetchCurrentReading() async throws -> GlucoseReading {
        // Try with existing tokens if available
        if let jwt = keychain.get(KeychainHelper.Key.jwtToken),
           let accountIdHash = storage.accountIdHash,
           let patientId = storage.patientId {
            do {
                return try await getGraph(patientId: patientId, jwtToken: jwt, accountIdHash: accountIdHash)
            } catch let error as LibreLinkUpError {
                // If token expired (401 / 403), proceed to silent re-auth below
                switch error {
                case .invalidResponse(let statusCode, _):
                    if statusCode != 401 && statusCode != 403 {
                        throw error
                    }
                default:
                    throw error
                }
            }
        }
        
        // Silent re-authentication path
        guard let email = keychain.get(KeychainHelper.Key.email),
              let password = keychain.get(KeychainHelper.Key.password),
              !email.isEmpty, !password.isEmpty else {
            throw LibreLinkUpError.missingCredentials
        }
        
        let (jwt, accountIdHash) = try await login(email: email, password: password)
        let patientId = try await getConnections(jwtToken: jwt, accountIdHash: accountIdHash)
        return try await getGraph(patientId: patientId, jwtToken: jwt, accountIdHash: accountIdHash)
    }
}
