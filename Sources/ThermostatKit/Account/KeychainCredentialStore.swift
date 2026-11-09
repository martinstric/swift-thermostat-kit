//
//  KeychainCredentialStore.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation
import Security

public struct KeychainCredentialStore: CredentialStore {
    
    public let service: String
    public let accessGroup: String?
    
    public init(service: String = "ThermostatKit.account", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true, // matters on macOS; iOS ignores it
        ]
        
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
    
    public func load() throws(CredentialStoreError) -> Credentials? {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        
        var result: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecSuccess: break
        case errSecItemNotFound: return nil
        case let status: throw .keychain(status)
        }
        
        guard let item = result as? [String: Any],
              let username = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else { throw .corruptData }
        
        return Credentials(username: username, password: password)
    }
    
    public func save(_ credentials: Credentials) throws(CredentialStoreError) {
        let attributes: [String: Any] = [
            kSecAttrAccount as String: credentials.username,
            kSecValueData as String: Data(credentials.password.utf8)
        ]
        
        // Update first so a failed add can never wipe working credentials
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery.merging(attributes) { $1 }
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else { throw .keychain(status) }
    }
    
    public func delete() throws(CredentialStoreError) {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .keychain(status)
        }
    }
}
