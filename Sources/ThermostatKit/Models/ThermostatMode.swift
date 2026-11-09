//
//  ThermostatMode.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

public enum ThermostatMode: String, CaseIterable, Hashable, Sendable {
    case heat, cool, auto, off
}

extension ThermostatMode: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .heat: "Heat"
        case .cool: "Cool"
        case .auto: "Auto"
        case .off: "Off"
        }
    }
}
