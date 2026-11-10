import Foundation
import Security

public protocol KeychainManaging {
    func get(_ key: String) -> String?
    @discardableResult func set(_ value: String?, forKey key: String) -> Bool
    @discardableResult func delete(_ key: String) -> Bool
    func clearAll()
}

public final class KeychainHelper: KeychainManaging {
    public static let shared = KeychainHelper()
    
    public static let defaultService = "com.hanskrebs.locksugar"
    public static let defaultAccessGroup = "group.com.hanskrebs.locksugar"
    
    // Keys
    public enum Key {
        public static let email = "llu_email"
        public static let password = "llu_password"
        public static let jwtToken = "llu_jwt_token"
    }
    
    public let service: String
    public let accessGroup: String?
    
    // In-memory fallback for testing environments without Keychain entitlements
    private var inMemoryStore: [String: String]?
    
    public init(
        service: String = defaultService,
        accessGroup: String? = defaultAccessGroup,
        useInMemoryFallbackForTests: Bool = false
    ) {
        self.service = service
        self.accessGroup = accessGroup
        if useInMemoryFallbackForTests {
            self.inMemoryStore = [:]
        }
    }
    
    // MARK: - Convenient Accessors
    
    public var email: String? {
        get { get(Key.email) }
        set { set(newValue, forKey: Key.email) }
    }
    
    public var password: String? {
        get { get(Key.password) }
        set { set(newValue, forKey: Key.password) }
    }
    
    public var jwtToken: String? {
        get { get(Key.jwtToken) }
        set { set(newValue, forKey: Key.jwtToken) }
    }
    
    // MARK: - Keychain CRUD
    
    public func get(_ key: String) -> String? {
        if let memory = inMemoryStore {
            return memory[key]
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // If query failed due to missing access group entitlement (e.g. CLI runner), try without accessGroup
        if (status == errSecMissingEntitlement || status == errSecItemNotFound) && accessGroup != nil {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        
        guard status == errSecSuccess, let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    @discardableResult
    public func set(_ value: String?, forKey key: String) -> Bool {
        if inMemoryStore != nil {
            if let value = value {
                inMemoryStore?[key] = value
            } else {
                inMemoryStore?.removeValue(forKey: key)
            }
            return true
        }
        
        guard let value = value, let data = value.data(using: .utf8) else {
            return delete(key)
        }
        
        // First delete any existing item
        delete(key)
        
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        if let accessGroup = accessGroup {
            attributes[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var status = SecItemAdd(attributes as CFDictionary, nil)
        
        // Fallback without accessGroup if entitlement is missing
        if status == errSecMissingEntitlement && accessGroup != nil {
            attributes.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        
        return status == errSecSuccess
    }
    
    @discardableResult
    public func delete(_ key: String) -> Bool {
        if inMemoryStore != nil {
            inMemoryStore?.removeValue(forKey: key)
            return true
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var status = SecItemDelete(query as CFDictionary)
        if status == errSecMissingEntitlement && accessGroup != nil {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemDelete(query as CFDictionary)
        }
        
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    public func clearAll() {
        if inMemoryStore != nil {
            inMemoryStore?.removeAll()
            return
        }
        delete(Key.email)
        delete(Key.password)
        delete(Key.jwtToken)
    }
}
