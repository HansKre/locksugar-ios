import Foundation
#if canImport(LockSugarCore)
import LockSugarCore
#endif

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
    
    // Always formatted as integer without float part
    let floatReading = GlucoseReading(
        value: 6.9,
        valueInMgPerDl: 124,
        glucoseUnits: .mmolPerL,
        timestamp: Date()
    )
    assertEqual(floatReading.formattedValue, "7")
    
    let floatEvenReading = GlucoseReading(
        value: 5.0,
        valueInMgPerDl: 90,
        glucoseUnits: .mmolPerL,
        timestamp: Date()
    )
    assertEqual(floatEvenReading.formattedValue, "5")
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

runTest("GlucoseZone.classificationAndColors") {
    // Threshold tests based on glucoseConfig.ts
    assertEqual(GlucoseZone.zone(for: 50), .veryLow)
    assertEqual(GlucoseZone.zone(for: 69), .veryLow)
    assertEqual(GlucoseZone.zone(for: 70), .low)
    assertEqual(GlucoseZone.zone(for: 99), .low)
    assertEqual(GlucoseZone.zone(for: 100), .normal)
    assertEqual(GlucoseZone.zone(for: 155), .normal)
    assertEqual(GlucoseZone.zone(for: 156), .elevated)
    assertEqual(GlucoseZone.zone(for: 189), .elevated)
    assertEqual(GlucoseZone.zone(for: 190), .high)
    assertEqual(GlucoseZone.zone(for: 249), .high)
    assertEqual(GlucoseZone.zone(for: 250), .veryHigh)
    assertEqual(GlucoseZone.zone(for: 350), .veryHigh)
    
    // Hex colors
    assertEqual(GlucoseZone.veryLow.hexColor, "#8B0000")
    assertEqual(GlucoseZone.low.hexColor, "#FF9800")
    assertEqual(GlucoseZone.normal.hexColor, "#4CAF50")
    assertEqual(GlucoseZone.elevated.hexColor, "#FF9800")
    assertEqual(GlucoseZone.high.hexColor, "#F44336")
    assertEqual(GlucoseZone.veryHigh.hexColor, "#8B0000")
}

runTest("GlucoseReading.trendArrows") {
    let reading1 = GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: Date(), trendArrow: 1)
    assertEqual(reading1.trendArrowSymbol, "↓")
    
    let reading2 = GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: Date(), trendArrow: 2)
    assertEqual(reading2.trendArrowSymbol, "↘")
    
    let reading3 = GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: Date(), trendArrow: 3)
    assertEqual(reading3.trendArrowSymbol, "→")
    
    let reading4 = GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: Date(), trendArrow: 4)
    assertEqual(reading4.trendArrowSymbol, "↗")
    
    let reading5 = GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: Date(), trendArrow: 5)
    assertEqual(reading5.trendArrowSymbol, "↑")
    
    let readingNil = GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: Date(), trendArrow: nil)
    assertEqual(readingNil.trendArrowSymbol, "→")
}

runTest("GlucoseForecastCalculator.projections") {
    let now = Date()
    
    // 1. Sparse data (< 3 points) returns empty
    let sparse = [
        GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: now)
    ]
    let sparseProj = GlucoseForecastCalculator.calculateProjection(from: sparse)
    assertTrue(sparseProj.isEmpty)
    
    // 2. Falling trend: 130 -> 120 -> 110 -> 100 (every 10 minutes)
    let fallingHistory = [
        GlucoseReading(value: 130, valueInMgPerDl: 130, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-30 * 60)),
        GlucoseReading(value: 120, valueInMgPerDl: 120, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-20 * 60)),
        GlucoseReading(value: 110, valueInMgPerDl: 110, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-10 * 60)),
        GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: now)
    ]
    let fallingProj = GlucoseForecastCalculator.calculateProjection(from: fallingHistory, minutesAhead: 30)
    assertTrue(!fallingProj.isEmpty)
    assertTrue(fallingProj.count >= 2)
    // First projected point should be lower than last reading (100)
    assertTrue(fallingProj[0].value < 100.0)
    // Points should continue to descend
    assertTrue(fallingProj.last!.value < fallingProj[0].value)
    // Uncertainty band widens over time
    let firstBandWidth = fallingProj[0].upperBound - fallingProj[0].lowerBound
    let lastBandWidth = fallingProj.last!.upperBound - fallingProj.last!.lowerBound
    assertTrue(lastBandWidth > firstBandWidth)
    
    // 3. Rising trend: 90 -> 100 -> 110 -> 120
    let risingHistory = [
        GlucoseReading(value: 90, valueInMgPerDl: 90, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-30 * 60)),
        GlucoseReading(value: 100, valueInMgPerDl: 100, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-20 * 60)),
        GlucoseReading(value: 110, valueInMgPerDl: 110, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-10 * 60)),
        GlucoseReading(value: 120, valueInMgPerDl: 120, glucoseUnits: .mgPerDl, timestamp: now)
    ]
    let risingProj = GlucoseForecastCalculator.calculateProjection(from: risingHistory, minutesAhead: 30)
    assertTrue(!risingProj.isEmpty)
    assertTrue(risingProj[0].value > 120.0)
    assertTrue(risingProj.last!.value > risingProj[0].value)
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
    assertEqual(reading?.formattedValue, "182")
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

runTest("SharedStorage.historyAndTargets") {
    let defaults = UserDefaults(suiteName: "test.suite.\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    
    // Initially empty
    assertTrue(storage.cachedGlucoseHistory.isEmpty)
    assertTrue(storage.targetLow == nil)
    assertTrue(storage.targetHigh == nil)
    
    // Store targets and history
    storage.targetLow = 70.0
    storage.targetHigh = 180.0
    assertEqual(storage.targetLow, 70.0)
    assertEqual(storage.targetHigh, 180.0)
    
    let now = Date()
    let history = [
        GlucoseReading(value: 110, valueInMgPerDl: 110, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-15 * 60)),
        GlucoseReading(value: 115, valueInMgPerDl: 115, glucoseUnits: .mgPerDl, timestamp: now)
    ]
    storage.cachedGlucoseHistory = history
    assertEqual(storage.cachedGlucoseHistory.count, 2)
    assertEqual(storage.cachedGlucoseHistory[0].valueInMgPerDl, 110.0)
    assertEqual(storage.cachedGlucoseHistory[1].valueInMgPerDl, 115.0)
    
    // Test dynamic Y-axis setting
    assertTrue(storage.isDynamicYAxisEnabled == true) // Default true
    storage.isDynamicYAxisEnabled = false
    assertEqual(storage.isDynamicYAxisEnabled, false)
    storage.isDynamicYAxisEnabled = true
    assertEqual(storage.isDynamicYAxisEnabled, true)
    
    // Clear all
    storage.clearAll()
    assertTrue(storage.cachedGlucoseHistory.isEmpty)
    assertTrue(storage.targetLow == nil)
    assertTrue(storage.targetHigh == nil)
    assertTrue(storage.isDynamicYAxisEnabled == true)
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

await runAsyncTest("LibreLinkUpClient.freshestReadingFromGraphData") {
    MockURLProtocol.reset()
    let defaults = UserDefaults(suiteName: "test.suite.\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    let keychain = KeychainHelper(useInMemoryFallbackForTests: true)
    let session = MockURLProtocol.makeMockSession()
    let client = LibreLinkUpClient(session: session, keychain: keychain, storage: storage)
    
    // Stale measurement in connection.glucoseMeasurement (10:00 AM), fresher measurement in graphData (10:15 AM)
    MockURLProtocol.requestHandler = { request in
        let json = """
        {
            "status": 0,
            "data": {
                "connection": {
                    "glucoseMeasurement": {
                        "Timestamp": "4/1/2026 10:00:00 AM",
                        "ValueInMgPerDl": 100,
                        "GlucoseUnits": 0,
                        "Value": 100
                    }
                },
                "graphData": [
                    {
                        "Timestamp": "4/1/2026 9:45:00 AM",
                        "ValueInMgPerDl": 95,
                        "GlucoseUnits": 0,
                        "Value": 95
                    },
                    {
                        "Timestamp": "4/1/2026 10:15:00 AM",
                        "ValueInMgPerDl": 142,
                        "GlucoseUnits": 0,
                        "Value": 142
                    }
                ]
            }
        }
        """
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(json.utf8))
    }
    
    let reading = try await client.getGraph(patientId: "p1", jwtToken: "tok", accountIdHash: "hash")
    assertEqual(reading.formattedValue, "142")
    assertEqual(reading.valueInMgPerDl, 142)
}

runTest("TimelineScheduler.calculateNextReloadDate") {
    let now = Date()
    // 1. Fresh measurement: 1 minute ago -> next reload should be now - 1m + 5m 15s = now + 4m 15s
    let measurement1MinAgo = now.addingTimeInterval(-60)
    let reload1 = TimelineScheduler.calculateNextReloadDate(for: measurement1MinAgo, from: now)
    let expected1 = measurement1MinAgo.addingTimeInterval(5 * 60 + 15)
    assertEqual(Int(reload1.timeIntervalSince(now)), Int(expected1.timeIntervalSince(now)))
    
    // 2. Old measurement: 10 minutes ago -> target reload (now - 10m + 5m 15s) is in the past -> fallback to now + 5 min
    let oldMeasurement = now.addingTimeInterval(-10 * 60)
    let reloadOld = TimelineScheduler.calculateNextReloadDate(for: oldMeasurement, from: now)
    assertEqual(Int(reloadOld.timeIntervalSince(now)), 5 * 60)
    
    // 3. Nil measurement -> fallback to now + 5 min
    let reloadNil = TimelineScheduler.calculateNextReloadDate(for: nil, from: now)
    assertEqual(Int(reloadNil.timeIntervalSince(now)), 5 * 60)
}

runTest("GlucoseReading.deltaCalculation") {
    let now = Date()
    let current = GlucoseReading(value: 112, valueInMgPerDl: 112, glucoseUnits: .mgPerDl, timestamp: now)
    let prev1 = GlucoseReading(value: 114, valueInMgPerDl: 114, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-5 * 60))
    let prev2 = GlucoseReading(value: 110, valueInMgPerDl: 110, glucoseUnits: .mgPerDl, timestamp: now.addingTimeInterval(-10 * 60))
    
    // Negative delta (-2)
    let deltaNeg = GlucoseReading.calculateDelta(current: current, history: [prev2, prev1])
    assertEqual(deltaNeg, -2.0)
    assertEqual(GlucoseReading.formatDelta(deltaNeg), "-2")
    
    // Positive delta (+4)
    let deltaPos = GlucoseReading.calculateDelta(current: prev1, history: [prev2])
    assertEqual(deltaPos, 4.0)
    assertEqual(GlucoseReading.formatDelta(deltaPos), "+4")
    
    // Fallback for empty history
    let deltaEmpty = GlucoseReading.calculateDelta(current: current, history: [])
    assertEqual(deltaEmpty, nil)
    assertEqual(GlucoseReading.formatDelta(deltaEmpty), "--")
}

runTest("HeadphoneBatteryInfo.formattingAndCodable") {
    let connected = HeadphoneBatteryInfo(isConnected: true, batteryLevel: 85, deviceName: "AirPods Pro")
    assertTrue(connected.isConnected)
    assertEqual(connected.batteryLevel, 85)
    assertEqual(connected.deviceName, "AirPods Pro")
    assertEqual(connected.formattedPercentage, "85%")
    
    let noBattery = HeadphoneBatteryInfo(isConnected: true, batteryLevel: nil, deviceName: "Bluetooth Speaker")
    assertTrue(noBattery.isConnected)
    assertEqual(noBattery.formattedPercentage, nil)
    
    let disconnected = HeadphoneBatteryInfo(isConnected: false, batteryLevel: nil, deviceName: nil)
    assertFalse(disconnected.isConnected)
    assertEqual(disconnected.formattedPercentage, nil)
    
    // Codable verification
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(connected)
    let decoded = try decoder.decode(HeadphoneBatteryInfo.self, from: data)
    assertEqual(decoded, connected)
    assertEqual(decoded.formattedPercentage, "85%")
}

runTest("SharedStorage.headphoneBatteryAndToggle") {
    let defaults = UserDefaults(suiteName: "test_suite_headphone_\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    
    // 1. Default toggle is true
    assertTrue(storage.showHeadphoneBattery)
    
    // 2. Change toggle to false
    storage.showHeadphoneBattery = false
    assertFalse(storage.showHeadphoneBattery)
    
    // 3. Re-enable toggle
    storage.showHeadphoneBattery = true
    assertTrue(storage.showHeadphoneBattery)
    
    // 4. Default headphone info is nil
    assertEqual(storage.headphoneBatteryInfo, nil)
    
    // 5. Update headphone battery (connected)
    storage.updateHeadphoneBattery(isConnected: true, batteryLevel: 78, deviceName: "Bose QC45")
    let info = storage.headphoneBatteryInfo
    assertTrue(info != nil)
    assertTrue(info?.isConnected == true)
    assertEqual(info?.batteryLevel, 78)
    assertEqual(info?.deviceName, "Bose QC45")
    assertEqual(info?.formattedPercentage, "78%")
    
    // 6. Update headphone battery (disconnected)
    storage.updateHeadphoneBattery(isConnected: false, batteryLevel: nil, deviceName: nil)
    let discInfo = storage.headphoneBatteryInfo
    assertTrue(discInfo != nil)
    assertFalse(discInfo?.isConnected == true)
    assertEqual(discInfo?.formattedPercentage, nil)
    
    // 7. Clear all removes headphone info
    storage.clearAll()
    assertEqual(storage.headphoneBatteryInfo, nil)
}

runTest("SharedStorage.widgetTapActionAndURL") {
    let defaults = UserDefaults(suiteName: "test_suite_widget_url_\(UUID().uuidString)")!
    let storage = SharedStorage(userDefaults: defaults)
    
    // 1. Default is .libre3Direct
    assertEqual(storage.widgetTapAction, .libre3Direct)
    assertEqual(storage.resolvedWidgetURL, URL(string: "freestylelibre3://"))
    assertTrue(storage.widgetLaunchURL.absoluteString.starts(with: "locksugar://widget-tap?target="))
    assertTrue(storage.widgetLaunchURL.absoluteString.contains("freestylelibre3"))
    
    // 2. Change to .libre3Shortcut
    storage.widgetTapAction = .libre3Shortcut
    assertEqual(storage.widgetTapAction, .libre3Shortcut)
    assertEqual(storage.resolvedWidgetURL, URL(string: "shortcuts://run-shortcut?name=Libre%203"))
    assertTrue(storage.widgetLaunchURL.absoluteString.contains("shortcuts"))
    
    // 3. Change to .lockSugar
    storage.widgetTapAction = .lockSugar
    assertEqual(storage.widgetTapAction, .lockSugar)
    assertEqual(storage.resolvedWidgetURL, URL(string: "locksugar://"))
    assertEqual(storage.widgetLaunchURL, URL(string: "locksugar://open"))
    
    // 4. Change to .custom
    storage.widgetTapAction = .custom
    storage.widgetTapCustomURL = "mycgm://action"
    assertEqual(storage.widgetTapAction, .custom)
    assertEqual(storage.resolvedWidgetURL, URL(string: "mycgm://action"))
    assertTrue(storage.widgetLaunchURL.absoluteString.contains("mycgm"))
    
    // 5. Clear all restores default
    storage.clearAll()
    assertEqual(storage.widgetTapAction, .libre3Direct)
    assertEqual(storage.widgetTapCustomURL, "")
    assertEqual(storage.resolvedWidgetURL, URL(string: "freestylelibre3://"))
}

runTest("GlucoseReading.deltaWithTrendArrowFormatting") {
    let now = Date()
    let reading1 = GlucoseReading(value: 112, valueInMgPerDl: 112, glucoseUnits: .mgPerDl, timestamp: now, trendArrow: 3)
    let delta1 = 5.0
    let text1 = "\(reading1.formattedValue) \(reading1.trendArrowSymbol) \(GlucoseReading.formatDelta(delta1))"
    assertEqual(text1, "112 → +5")
    
    let reading2 = GlucoseReading(value: 95, valueInMgPerDl: 95, glucoseUnits: .mgPerDl, timestamp: now, trendArrow: 2)
    let delta2 = -3.0
    let text2 = "\(reading2.formattedValue) \(reading2.trendArrowSymbol) \(GlucoseReading.formatDelta(delta2))"
    assertEqual(text2, "95 ↘ -3")
    
    let reading3 = GlucoseReading(value: 150, valueInMgPerDl: 150, glucoseUnits: .mgPerDl, timestamp: now, trendArrow: 5)
    let delta3: Double? = nil
    let text3 = delta3 != nil ? "\(reading3.formattedValue) \(reading3.trendArrowSymbol) \(GlucoseReading.formatDelta(delta3))" : "\(reading3.formattedValue) \(reading3.trendArrowSymbol)"
    assertEqual(text3, "150 ↑")
}

runTest("GlucoseReading.trendArrowDefinitions") {
    let defs = TrendArrowDefinition.allDefinitions
    assertEqual(defs.count, 5)
    
    // Check mapping 5 -> ↑
    let def5 = TrendArrowDefinition.definition(for: 5)
    assertEqual(def5.symbol, "↑")
    assertEqual(def5.title, "Rising Quickly")
    assertTrue(def5.rateMgPerDl.contains("> 2 mg/dL"))
    assertTrue(def5.rateMmolPerL.contains("> 0.11 mmol/L"))
    
    // Check mapping 3 -> → (stable)
    let def3 = TrendArrowDefinition.definition(for: 3)
    assertEqual(def3.symbol, "→")
    assertEqual(def3.title, "Changing Slowly / Stable")
    assertTrue(def3.rateMgPerDl.contains("< 1 mg/dL"))
    
    // Check mapping 1 -> ↓
    let def1 = TrendArrowDefinition.definition(for: 1)
    assertEqual(def1.symbol, "↓")
    assertEqual(def1.title, "Falling Quickly")
    
    // Fallback for nil or unknown maps to stable (3)
    let defNil = TrendArrowDefinition.definition(for: nil)
    assertEqual(defNil.symbol, "→")
    assertEqual(defNil.id, 3)
}

print("=== All Tests Passed Successfully ===")
