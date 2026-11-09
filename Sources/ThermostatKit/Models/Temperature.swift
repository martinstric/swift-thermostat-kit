//
//  Temperature.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation

public struct Temperature: Sendable, Hashable, Comparable {
    
    public var celsius: Double
    
    public init(celsius: Double) {
        self.celsius = celsius
    }
    
    public static func celsius(_ value: Double) -> Temperature {
        Temperature(celsius: value)
    }
    
    public static func fahrenheit(_ value: Double) -> Temperature {
        Temperature(celsius: (value - 32) * 5 / 9)
    }
    
    public var fahrenheit: Double { celsius * 9 / 5 + 32 }
    
    /// Use for display: `Text(temperature.measurement, format: .measurement(width: .narrow))`
    public var measurement: Measurement<UnitTemperature> {
        Measurement(value: celsius, unit: .celsius)
    }
    
    public func rounded(toNearest step: Double = 0.5) -> Temperature {
        .celsius((celsius / step).rounded() * step)
    }
    
    public func clamped(to range: ClosedRange<Temperature>) -> Temperature {
        min(max(self, range.lowerBound), range.upperBound)
    }
    
    public static func < (lhs: Temperature, rhs: Temperature) -> Bool {
        lhs.celsius < rhs.celsius
    }
}

public enum TemperatureScale: Sendable, Hashable {
    case celsius, fahrenheit
}

extension Temperature {
    
    public init(_ value: Double, in scale: TemperatureScale) {
        switch scale {
        case .celsius: self = .celsius(value)
        case .fahrenheit: self = .fahrenheit(value)
        }
    }
}

extension Temperature: CustomStringConvertible {
    
    public var description: String {
        measurement.formatted()
    }
}
