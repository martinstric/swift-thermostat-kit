//
//  ThermostatError.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation

public enum ThermostatError: Error, LocalizedError, CustomStringConvertible {
    case loginFailed
    case notAuthenticated
    case missingCredentials
    case credentialStore(CredentialStoreError)
    case invalidConfiguration(reason: String)
    case deviceIDNotFound
    case badResponse
    case unexpectedStatus(Int)
    case encodingFailed(any Error)
    case decodingFailed(any Error)
    case transport(URLError)

    public var errorDescription: String? {
        switch self {
        case .loginFailed: "Login failed. Check your username and password."
        case .notAuthenticated: "Your session expired."
        case .missingCredentials: "You're not signed in."
        case .credentialStore(let error): "Couldn't access saved credentials: \(error)"
        case .invalidConfiguration(let reason): reason
        case .deviceIDNotFound: "Couldn't find this thermostat's device ID."
        case .badResponse: "The server returned an invalid response."
        case .unexpectedStatus(let code): "The server returned HTTP \(code)."
        case .encodingFailed(let error): "Couldn't encode the command: \(error)"
        case .decodingFailed(let error): "Couldn't read the thermostat's status: \(error)"
        case .transport(let error): error.localizedDescription
        }
    }

    public var description: String { errorDescription ?? "Unknown error" }
}
