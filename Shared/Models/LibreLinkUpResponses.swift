import Foundation

// MARK: - LibreLinkUp Error Response
public struct LLUErrorResponse: Codable {
    public let status: Int?
    public let error: LLUErrorDetail?
    public let data: LLUErrorData?
    
    public init(status: Int? = nil, error: LLUErrorDetail? = nil, data: LLUErrorData? = nil) {
        self.status = status
        self.error = error
        self.data = data
    }
}

public struct LLUErrorDetail: Codable {
    public let message: String?
    
    public init(message: String? = nil) {
        self.message = message
    }
}

public struct LLUErrorData: Codable {
    public let minimumVersion: String?
    
    public init(minimumVersion: String? = nil) {
        self.minimumVersion = minimumVersion
    }
}

// MARK: - Login Response
public struct LLULoginResponse: Codable {
    public let status: Int?
    public let error: LLUErrorDetail?
    public let data: LLULoginData?
    
    public init(status: Int? = nil, error: LLUErrorDetail? = nil, data: LLULoginData? = nil) {
        self.status = status
        self.error = error
        self.data = data
    }
}

public struct LLULoginData: Codable {
    public let authTicket: LLUAuthTicket?
    public let user: LLUUser?
    public let redirect: Bool?
    public let region: String?
    public let minimumVersion: String?
    
    public init(
        authTicket: LLUAuthTicket? = nil,
        user: LLUUser? = nil,
        redirect: Bool? = nil,
        region: String? = nil,
        minimumVersion: String? = nil
    ) {
        self.authTicket = authTicket
        self.user = user
        self.redirect = redirect
        self.region = region
        self.minimumVersion = minimumVersion
    }
}

public struct LLUAuthTicket: Codable {
    public let token: String?
    public let expires: Int?
    public let duration: Int?
    
    public init(token: String? = nil, expires: Int? = nil, duration: Int? = nil) {
        self.token = token
        self.expires = expires
        self.duration = duration
    }
}

public struct LLUUser: Codable {
    public let id: String?
    public let country: String?
    
    public init(id: String? = nil, country: String? = nil) {
        self.id = id
        self.country = country
    }
}

// MARK: - Connections Response
public struct LLUConnectionsResponse: Codable {
    public let status: Int?
    public let error: LLUErrorDetail?
    public let data: [LLUConnectionItem]?
    
    public init(status: Int? = nil, error: LLUErrorDetail? = nil, data: [LLUConnectionItem]? = nil) {
        self.status = status
        self.error = error
        self.data = data
    }
}

public struct LLUConnectionItem: Codable {
    public let id: String?
    public let patientId: String?
    public let firstName: String?
    public let lastName: String?
    public let country: String?
    public let status: Int?
    
    public init(
        id: String? = nil,
        patientId: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        country: String? = nil,
        status: Int? = nil
    ) {
        self.id = id
        self.patientId = patientId
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.status = status
    }
}

// MARK: - Graph Response
public struct LLUGraphResponse: Codable {
    public let status: Int?
    public let error: LLUErrorDetail?
    public let data: LLUConnectionData?
    
    public init(status: Int? = nil, error: LLUErrorDetail? = nil, data: LLUConnectionData? = nil) {
        self.status = status
        self.error = error
        self.data = data
    }
}

public struct LLUConnectionData: Codable {
    public let connection: LLUConnection?
    public let graphData: [LLUGlucoseMeasurement]?
    
    public init(connection: LLUConnection? = nil, graphData: [LLUGlucoseMeasurement]? = nil) {
        self.connection = connection
        self.graphData = graphData
    }
}

public struct LLUConnection: Codable {
    public let id: String?
    public let patientId: String?
    public let glucoseMeasurement: LLUGlucoseMeasurement?
    public let glucoseItem: LLUGlucoseMeasurement?
    public let targetLow: Double?
    public let targetHigh: Double?
    public let uom: Int?
    
    public init(
        id: String? = nil,
        patientId: String? = nil,
        glucoseMeasurement: LLUGlucoseMeasurement? = nil,
        glucoseItem: LLUGlucoseMeasurement? = nil,
        targetLow: Double? = nil,
        targetHigh: Double? = nil,
        uom: Int? = nil
    ) {
        self.id = id
        self.patientId = patientId
        self.glucoseMeasurement = glucoseMeasurement
        self.glucoseItem = glucoseItem
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.uom = uom
    }
}

public struct LLUGlucoseMeasurement: Codable {
    public let factoryTimestamp: String?
    public let timestamp: String
    public let type: Int?
    public let valueInMgPerDl: Double
    public let trendArrow: Int?
    public let trendMessage: String?
    public let measurementColor: Int?
    public let glucoseUnits: Int
    public let value: Double
    public let isHigh: Bool?
    public let isLow: Bool?
    
    enum CodingKeys: String, CodingKey {
        case factoryTimestamp = "FactoryTimestamp"
        case timestamp = "Timestamp"
        case type
        case valueInMgPerDl = "ValueInMgPerDl"
        case trendArrow = "TrendArrow"
        case trendMessage = "TrendMessage"
        case measurementColor = "MeasurementColor"
        case glucoseUnits = "GlucoseUnits"
        case value = "Value"
        case isHigh
        case isLow
    }
    
    public init(
        factoryTimestamp: String? = nil,
        timestamp: String,
        type: Int? = nil,
        valueInMgPerDl: Double,
        trendArrow: Int? = nil,
        trendMessage: String? = nil,
        measurementColor: Int? = nil,
        glucoseUnits: Int,
        value: Double,
        isHigh: Bool? = nil,
        isLow: Bool? = nil
    ) {
        self.factoryTimestamp = factoryTimestamp
        self.timestamp = timestamp
        self.type = type
        self.valueInMgPerDl = valueInMgPerDl
        self.trendArrow = trendArrow
        self.trendMessage = trendMessage
        self.measurementColor = measurementColor
        self.glucoseUnits = glucoseUnits
        self.value = value
        self.isHigh = isHigh
        self.isLow = isLow
    }
}
