//
//  CredentialStore.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation

public protocol CredentialStore: Sendable {
    func load() throws(CredentialStoreError) -> Credentials?
    func save(_ credentials: Credentials) throws(CredentialStoreError)
    func delete() throws(CredentialStoreError)
}

public enum CredentialStoreError: Error, Sendable {
    case keychain(OSStatus)
    case corruptData
}
