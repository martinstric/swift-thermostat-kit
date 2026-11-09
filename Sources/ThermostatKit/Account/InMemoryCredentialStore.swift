//
//  InMemoryCredentialStore.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Synchronization

public final class InMemoryCredentialStore: CredentialStore {
    
    private let storage: Mutex<Credentials?>
    
    public init(_ credentials: Credentials? = nil) { storage = Mutex(credentials) }
    
    public func load() -> Credentials? { storage.withLock { $0 } }
    public func save(_ credentials: Credentials) { storage.withLock { $0 = credentials } }
    public func delete() { storage.withLock { $0 = nil } }
}
