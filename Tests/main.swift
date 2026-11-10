import Foundation
import LockSugarCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        print("❌ Assertion Failed: Expected [\(expected)], got [\(actual)] - \(message) at \(file):\(line)")
        exit(1)
    }
}

func runTest(_ name: String, block: () throws -> Void) rethrows {
    print("▶️ Running \(name)...")
    try block()
    print("✅ Passed \(name)")
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
}

print("=== All Tests Passed Successfully ===")
