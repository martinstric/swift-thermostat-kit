//
//  WireMapping.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

enum WireError: Error {
    case unknownValue(field: String, value: String)
}

protocol WireRepresentable: CaseIterable {
    static var wireField: String { get }
    var wireValue: String { get }
}

extension WireRepresentable {
    
    init(wireValue: String) throws(WireError) {
        guard let match = Self.allCases.first(where: { $0.wireValue == wireValue }) else {
            throw .unknownValue(field: Self.wireField, value: wireValue)
        }
        
        self = match
    }
}

extension ThermostatMode: WireRepresentable {
    
    static let wireField = "mode"
    
    var wireValue: String {
        switch self {
        case .heat: "heat"
        case .cool: "cool"
        case .auto: "auto"
        case .off: "off"
        }
    }
}

extension FanMode: WireRepresentable {
    
    static let wireField = "fan"
    
    var wireValue: String {
        switch self {
        case .high: "high"
        case .medium: "med"
        case .low: "low"
        case .auto: "auto"
        case .off: "off"
        }
    }
}

extension HoldMode: WireRepresentable {
    
    static let wireField = "temp_mode"
    
    var wireValue: String {
        switch self {
        case .permanent: "hold"
        case .temporary: "temp"
        case .schedule: "schedule"
        }
    }
}

extension Temperature {
    
    // TODO: Assumes the server speaks Celsius. If it's Fahrenheit, change these two lines.
    
    init(wireValue: Double) { self.init(celsius: wireValue) }
    var wireValue: Double { rounded(toNearest: 0.5).celsius }
}
