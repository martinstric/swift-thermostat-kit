//
//  ThermostatSettings.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation

public struct ThermostatSettings: Sendable, Hashable {
    
    public enum TimeFormat: Int, Sendable, Hashable {
        case h12 = 12, h24 = 24
    }
    
    public let name: String
    public let timeFormat: TimeFormat
    public let timezoneOffset: Int
    public let timezoneName: String
    public let updatedAt: Date
}
