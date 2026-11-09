//
//  ModelTests.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Testing
@testable import ThermostatKit

@Suite struct TemperatureTests {
    
    @Test func convertsBetweenScales() {
        #expect(Temperature.celsius(0).fahrenheit == 32)
        #expect(isApproximately(Temperature.fahrenheit(212).celsius, 100))
    }

    @Test(arguments: [(21.3, 0.5, 21.5), (21.2, 0.5, 21.0), (22.4, 1, 22), (22.5, 1, 23)])
    func rounding(value: Double, step: Double, expected: Double) {
        #expect(Temperature.celsius(value).rounded(toNearest: step) == .celsius(expected))
    }

    @Test func wireValueIsWholeCelsius() {
        #expect(Temperature.celsius(20.6).wireValue == 21)
        #expect(Temperature.fahrenheit(70).wireValue == 21)  // 21.1°C
    }
}

@Suite struct ConfigurationTests {
    
    func configuration(setpoint: Double) -> ThermostatConfiguration {
        ThermostatConfiguration(mode: .heat, fan: .auto, holdMode: .permanent, setpoint: .celsius(setpoint))
    }

    @Test func inRangeSetpointIsValid() throws {
        try configuration(setpoint: 21).validate()
    }

    @Test(arguments: [9.0, 41.0])
    func outOfRangeSetpointThrows(_ setpoint: Double) {
        let error = #expect(throws: ThermostatError.self) { try configuration(setpoint: setpoint).validate() }
        #expect(error?.isInvalidConfiguration == true)
    }

    @Test func normalizeClampsAndRounds() {
        var high = configuration(setpoint: 45)
        high.normalize()
        #expect(high.setpoint == .celsius(40))

        var fractional = configuration(setpoint: 22.4)
        fractional.normalize()
        #expect(fractional.setpoint == .celsius(22))
    }
}
