import Foundation

public struct HeadphoneBatteryInfo: Codable, Equatable {
    public let isConnected: Bool
    public let batteryLevel: Int?      // 0 - 100
    public let deviceName: String?
    public let updatedAt: Date
    
    public init(
        isConnected: Bool,
        batteryLevel: Int? = nil,
        deviceName: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.isConnected = isConnected
        self.batteryLevel = batteryLevel
        self.deviceName = deviceName
        self.updatedAt = updatedAt
    }
    
    public var formattedPercentage: String? {
        guard let level = batteryLevel else { return nil }
        return "\(level)%"
    }
}
