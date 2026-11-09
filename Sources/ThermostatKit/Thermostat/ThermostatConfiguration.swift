//
//  ThermostatConfiguration.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

public struct ThermostatConfiguration: Sendable, Hashable {
    
    public var mode: ThermostatMode
    public var fan: FanMode
    public var holdMode: HoldMode
    public var setpoint: Temperature
    /// Reported by the thermostat. Not sent back.
    public let setpointRange: ClosedRange<Temperature>
    
    public init(mode: ThermostatMode, fan: FanMode, holdMode: HoldMode, setpoint: Temperature, setpointRange: ClosedRange<Temperature> = .celsius(10) ... .celsius(40)) {
        self.mode = mode
        self.fan = fan
        self.holdMode = holdMode
        self.setpoint = setpoint
        self.setpointRange = setpointRange
    }
    
    // TODO: Placeholders. Check limits on the wall unit and the website's controls.
    public static let setpointRange: ClosedRange<Temperature> = .celsius(5) ... .celsius(35)
    public static let minimumAutoGap = 1.0 // ºC between heat and cool in auto mode
    
    public func validate() throws(ThermostatError) {
        guard setpointRange.contains(setpoint) else {
            throw .invalidConfiguration(reason: "\(setpoint) is outside \(setpointRange.lowerBound)–\(setpointRange.upperBound).")
        }
    }
    
    /// Clamps and rounds setpoints. Call after stepper changes so the UI never holds an invalid value.
    public mutating func normalize() {
        setpoint = setpoint.clamped(to: setpointRange).rounded(toNearest: 1)
    }
}
