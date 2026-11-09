//
//  FanMode.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

public enum FanMode: String, CaseIterable, Hashable, Sendable {
    case high, medium, low, auto, off
}

extension FanMode: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .auto: "Auto"
        case .off: "Off"
        }
    }
}
