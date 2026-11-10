import Foundation
import CryptoKit

public enum CryptoUtils {
    /// Computes the SHA-256 hash of a string and returns it as a lowercase hex string.
    /// Used by LibreLinkUp protocol for the `account-id` header: `sha256(user.id)`.
    public static func sha256Hex(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
