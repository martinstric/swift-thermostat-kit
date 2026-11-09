//
//  ThermostatStatus.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

import Foundation

@dynamicMemberLookup
public struct ThermostatStatus: Sendable, Hashable {
    
    public let configuration: ThermostatConfiguration
    public let currentTemperature: Temperature
    /// 0...1, if the thermostat reports it.
    public let humidity: Double?
    /// The scale the wall unit displays.
    public let scale: TemperatureScale
    /// When the thermostat last checked in with the server.
    public let lastSeen: Date?
    public let updatedAt: Date
    
    public init(configuration: ThermostatConfiguration, currentTemperature: Temperature, humidity: Double? = nil, scale: TemperatureScale = .celsius, lastSeen: Date? = nil, updatedAt: Date = .now) {
        self.configuration = configuration
        self.currentTemperature = currentTemperature
        self.humidity = humidity
        self.scale = scale
        self.lastSeen = lastSeen
        self.updatedAt = updatedAt
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<ThermostatConfiguration, T>) -> T {
        configuration[keyPath: keyPath]
    }
}
