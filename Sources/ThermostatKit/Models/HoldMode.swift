//
//  HoldMode.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

public enum HoldMode: String, CaseIterable, Hashable, Sendable {
    case permanent, temporary, schedule
}

extension HoldMode: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .permanent: "Permanent"
        case .temporary: "Temporary"
        case .schedule: "Schedule"
        }
    }
}
