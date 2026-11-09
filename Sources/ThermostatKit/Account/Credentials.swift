//
//  Credentials.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

public struct Credentials: Hashable, Sendable {
    
    public var username: String
    public var password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

extension Credentials: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    
    public var description: String {
        "Credentials(username: \(username), password: <redacted>)"
    }
    
    public var debugDescription: String { description }
    
    public var customMirror: Mirror {
        Mirror(self, children: ["username": username])
    }
}
