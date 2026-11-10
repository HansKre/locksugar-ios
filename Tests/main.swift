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
        timestamp: now.addingTimeInterval(-15 * 60) // 15 min ago
    )
    assertFalse(freshReading.isStale(relativeTo: now))
    
    let staleReading = GlucoseReading(
        value: 120,
        valueInMgPerDl: 120,
        glucoseUnits: .mgPerDl,
        timestamp: now.addingTimeInterval(-21 * 60) // 21 min ago
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
    assertEqual(reading?.formattedValue, "182.0") // glucoseUnits is 1 (mmol/L) in sample
}

print("=== All Tests Passed Successfully ===")
