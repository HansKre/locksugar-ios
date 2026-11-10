import Foundation
import LockSugarCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        print("❌ Assertion Failed: Expected [\(expected)], got [\(actual)] - \(message) at \(file):\(line)")
        exit(1)
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if !condition {
        print("❌ Assertion Failed: Expected true, got false - \(message) at \(file):\(line)")
        exit(1)
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if condition {
        print("❌ Assertion Failed: Expected false, got true - \(message) at \(file):\(line)")
        exit(1)
    }
}

func runTest(_ name: String, block: () throws -> Void) {
    print("▶️ Running \(name)...")
    do {
        try block()
        print("✅ Passed \(name)")
    } catch {
        print("❌ Test \(name) failed with error: \(error)")
        exit(1)
    }
}

func runAsyncTest(_ name: String, block: () async throws -> Void) async {
    print("▶️ Running \(name)...")
    do {
        try await block()
        print("✅ Passed \(name)")
    } catch {
        print("❌ Test \(name) failed with error: \(error)")
        exit(1)
    }
}

print("=== Running LockSugar Test Suite ===")

runTest("CryptoUtils.sha256Hex") {
    assertEqual(
        CryptoUtils.sha256Hex("test"),
        "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
    )
    assertEqual(
        CryptoUtils.sha256Hex(""),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
    assertEqual(
        CryptoUtils.sha256Hex("uuid-1234"),
        "af49d47531cc2985690efa69f83c285ec49e640638d105aaed1eda679509e57a"
    )
}

runTest("GlucoseReading.unitFormatting") {
    let mgReading = GlucoseReading(
        value: 124,
        valueInMgPerDl: 124,
        glucoseUnits: .mgPerDl,
        timestamp: Date()
    )
    assertEqual(mgReading.formattedValue, "124")
    
    let mmolReading = GlucoseReading(
        value: 6.9,
        valueInMgPerDl: 124,
        glucoseUnits: .mmolPerL,
        timestamp: Date()
    )
    assertEqual(mmolReading.formattedValue, "6.9")
    
    let mmolEvenReading = GlucoseReading(
        value: 5.0,
        valueInMgPerDl: 90,
        glucoseUnits: .mmolPerL,
        timestamp: Date()
    )
    assertEqual(mmolEvenReading.formattedValue, "5.0")
}

runTest("GlucoseReading.staleness") {
    let now = Date()
    let freshReading = GlucoseReading(
        value: 120,
        valueInMgPerDl: 120,
        glucoseUnits: .mgPerDl,
        timestamp: now.addingTimeInterval(-15 * 60)
    )
    assertFalse(freshReading.isStale(relativeTo: now))
    
    let staleReading = GlucoseReading(
        value: 120,
        valueInMgPerDl: 120,
        glucoseUnits: .mgPerDl,
        timestamp: now.addingTimeInterval(-21 * 60)
    )
    assertTrue(staleReading.isStale(relativeTo: now))
}

runTest("LibreLinkUpResponses.decodeGraph") {
    let jsonString = """
    {
      "status": 0,
      "data": {
        "connection": {
          "id": "sample-conn",
          "patientId": "patient-uuid-1",
          "targetLow": 70,
          "targetHigh": 180,
          "uom": 1,
          "glucoseMeasurement": {
            "FactoryTimestamp": "4/1/2026 7:14:42 AM",
            "Timestamp": "4/1/2026 10:14:42 AM",
            "type": 1,
            "ValueInMgPerDl": 182,
            "TrendArrow": 3,
            "TrendMessage": null,
            "MeasurementColor": 2,
            "GlucoseUnits": 1,
            "Value": 182,
            "isHigh": false,
            "isLow": false
          }
        }
      }
    }
    """
    
    let data = Data(jsonString.utf8)
    let response = try JSONDecoder().decode(LLUGraphResponse.self, from: data)
    assertEqual(response.status, 0)
    let measurement = response.data?.connection?.glucoseMeasurement
    assertTrue(measurement != nil)
    assertEqual(measurement?.value, 182.0)
    assertEqual(measurement?.glucoseUnits, 1)
    
    let reading = GlucoseReading(measurement: measurement!)
    assertTrue(reading != nil)
    assertEqual(reading?.formattedValue, "182.0")
}

runTest("KeychainHelper.inMemory") {
    let keychain = KeychainHelper(service: "test.service", accessGroup: nil, useInMemoryFallbackForTests: true)
    keychain.email = "test@example.com"
    keychain.password = "secret123"
    keychain.jwtToken = "jwt.token.abc"
    
    assertEqual(keychain.email, "test@example.com")
    assertEqual(keychain.password, "secret123")
    assertEqual(keychain.jwtToken, "jwt.token.abc")
    
    keychain.clearAll()
    assertTrue(keychain.email == nil)
    assertTrue(keychain.password == nil)
    assertTrue(keychain.jwtToken == nil)
}

runTest("SharedStorage.cacheAndRetrieve") {
    let defaults = UserDefaults(suiteName: "test.suite.\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    
    assertEqual(storage.apiBaseUrl, SharedStorage.defaultBaseUrl)
    assertEqual(storage.apiMinimumVersion, SharedStorage.defaultMinimumVersion)
    
    storage.accountIdHash = "hash123"
    storage.patientId = "patient-abc"
    storage.apiBaseUrl = "https://api-eu.libreview.io"
    storage.apiMinimumVersion = "4.17.0"
    
    let sampleReading = GlucoseReading(
        value: 135,
        valueInMgPerDl: 135,
        glucoseUnits: .mgPerDl,
        timestamp: Date()
    )
    storage.cachedGlucoseReading = sampleReading
    
    assertEqual(storage.accountIdHash, "hash123")
    assertEqual(storage.patientId, "patient-abc")
    assertEqual(storage.apiBaseUrl, "https://api-eu.libreview.io")
    assertEqual(storage.apiMinimumVersion, "4.17.0")
    assertEqual(storage.cachedGlucoseReading?.formattedValue, "135")
}

// MARK: - Client & Network Flow Tests

await runAsyncTest("LibreLinkUpClient.minimumVersionRetry") {
    MockURLProtocol.reset()
    let defaults = UserDefaults(suiteName: "test.suite.\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    let keychain = KeychainHelper(useInMemoryFallbackForTests: true)
    let session = MockURLProtocol.makeMockSession()
    let client = LibreLinkUpClient(session: session, keychain: keychain, storage: storage)
    
    var requestCount = 0
    MockURLProtocol.requestHandler = { request in
        requestCount += 1
        if requestCount == 1 {
            // Return 403 with minimumVersion requirement
            let json = """
            {
                "status": 403,
                "data": { "minimumVersion": "4.18.0" }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        } else {
            // Verify version header was updated in retry
            assertEqual(request.value(forHTTPHeaderField: "version"), "4.18.0")
            let json = """
            {
                "status": 0,
                "data": {
                    "authTicket": { "token": "test-jwt-token" },
                    "user": { "id": "test-user-id" }
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }
    
    let (jwt, accountIdHash) = try await client.login(email: "user@test.com", password: "pwd")
    assertEqual(jwt, "test-jwt-token")
    assertEqual(accountIdHash, CryptoUtils.sha256Hex("test-user-id"))
    assertEqual(storage.apiMinimumVersion, "4.18.0")
    assertEqual(requestCount, 2)
}

await runAsyncTest("LibreLinkUpClient.regionRedirect") {
    MockURLProtocol.reset()
    let defaults = UserDefaults(suiteName: "test.suite.\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    let keychain = KeychainHelper(useInMemoryFallbackForTests: true)
    let session = MockURLProtocol.makeMockSession()
    let client = LibreLinkUpClient(session: session, keychain: keychain, storage: storage)
    
    var requestCount = 0
    MockURLProtocol.requestHandler = { request in
        requestCount += 1
        if requestCount == 1 {
            // Return 200 with redirect to region "de"
            let json = """
            {
                "status": 0,
                "data": {
                    "redirect": true,
                    "region": "de"
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        } else {
            // Verify request goes to redirected URL
            assertTrue(request.url!.absoluteString.starts(with: "https://api-de.libreview.io"))
            let json = """
            {
                "status": 0,
                "data": {
                    "authTicket": { "token": "de-jwt-token" },
                    "user": { "id": "de-user-id" }
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }
    
    let (jwt, _) = try await client.login(email: "de@test.com", password: "pwd")
    assertEqual(jwt, "de-jwt-token")
    assertEqual(storage.apiBaseUrl, "https://api-de.libreview.io")
    assertEqual(requestCount, 2)
}

await runAsyncTest("LibreLinkUpClient.silentTokenRenewal") {
    MockURLProtocol.reset()
    let defaults = UserDefaults(suiteName: "test.suite.\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    let keychain = KeychainHelper(useInMemoryFallbackForTests: true)
    let session = MockURLProtocol.makeMockSession()
    let client = LibreLinkUpClient(session: session, keychain: keychain, storage: storage)
    
    // Store credentials in Keychain, but NO jwtToken or patientId
    keychain.email = "silent@test.com"
    keychain.password = "pass123"
    
    MockURLProtocol.requestHandler = { request in
        let urlStr = request.url!.absoluteString
        if urlStr.contains("/llu/auth/login") {
            let json = """
            {
                "status": 0,
                "data": {
                    "authTicket": { "token": "new-jwt-token" },
                    "user": { "id": "patient-user-id" }
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        } else if urlStr.contains("/llu/connections") && !urlStr.contains("/graph") {
            let json = """
            {
                "status": 0,
                "data": [
                    { "patientId": "target-patient-uuid", "firstName": "Alice" }
                ]
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        } else if urlStr.contains("/graph") {
            let json = """
            {
                "status": 0,
                "data": {
                    "connection": {
                        "glucoseMeasurement": {
                            "Timestamp": "4/1/2026 11:00:00 AM",
                            "ValueInMgPerDl": 115,
                            "GlucoseUnits": 0,
                            "Value": 115
                        }
                    }
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
        fatalError("Unexpected URL: \(urlStr)")
    }
    
    let reading = try await client.fetchCurrentReading()
    assertEqual(reading.formattedValue, "115")
    assertEqual(keychain.jwtToken, "new-jwt-token")
    assertEqual(storage.patientId, "target-patient-uuid")
    assertEqual(storage.cachedGlucoseReading?.formattedValue, "115")
}

print("=== All Tests Passed Successfully ===")
