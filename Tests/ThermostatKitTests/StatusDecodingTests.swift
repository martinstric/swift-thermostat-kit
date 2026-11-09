//
//  StatusDecodingTests.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation
import Testing
@testable import ThermostatKit

@Suite struct StatusDecodingTests {
    
    @Test func decodesRealResponse() throws {
        let status = try decodeStatus(fixture("status"))

        #expect(status.mode == .heat)
        #expect(status.fan == .auto)
        #expect(status.holdMode == .permanent)
        #expect(status.setpoint == .celsius(23))
        #expect(status.currentTemperature == .celsius(23))
        #expect(isApproximately(try #require(status.humidity), 0.489))
        #expect(status.scale == .celsius)
        #expect(status.setpointRange == .celsius(10) ... .celsius(40))
        #expect(status.lastSeen == Date.fixed.addingTimeInterval(-4))
    }

    /// The real response reports 23°C alongside 71°F. Only the active scale should be read.
    @Test func readsOnlyTheActiveScale() throws {
        let celsius = try decodeStatus(statusJSON(units: 0))
        #expect(celsius.setpoint == .celsius(23))

        let fahrenheit = try decodeStatus(statusJSON(units: 1))
        #expect(isApproximately(fahrenheit.setpoint.fahrenheit, 71))
    }

    @Test func acceptsNumbersSentAsStrings() throws {
        let status = try decodeStatus(statusJSON(hold: (#""23""#, #""71""#), humidity: #""48.9""#))
        #expect(status.setpoint == .celsius(23))
        #expect(isApproximately(try #require(status.humidity), 0.489))
    }

    @Test func reversedLimitsThrow() {
        #expect(throws: WireError.self) { try decodeStatus(statusJSON(limits: ("40", "10"))) }
    }

    @Test func unknownModeThrows() {
        #expect(throws: WireError.self) { try decodeStatus(statusJSON(mode: "turbo")) }
    }

    // MARK: Helpers

    private func decodeStatus(_ data: Data) throws -> ThermostatStatus {
        try ThermostatStatus(JSONDecoder().decode(StatusResponse.self, from: data), fetchedAt: .fixed)
    }

    /// A minimal response. Parameters are raw JSON fragments, so pass `#""23""#` for a string.
    private func statusJSON(
        units: Int = 0,
        mode: String = "heat",
        hold: (celsius: String, fahrenheit: String) = ("23", "71"),
        humidity: String = "48.9",
        limits: (min: String, max: String) = ("10", "40")
    ) -> Data {
        Data("""
        {
          "data": {"temperature": 23, "humidity": \(humidity)},
          "online_config": {
            "mode": "\(mode)", "fan": "auto", "temp_mode": "hold",
            "hold_temp": {"celsius": \(hold.celsius), "fahrenheit": \(hold.fahrenheit)}
          },
          "online_settings": {
            "units": \(units),
            "min_temp": {"celsius": \(limits.min), "fahrenheit": 50},
            "max_temp": {"celsius": \(limits.max), "fahrenheit": 104}
          },
          "last_seen": 4
        }
        """.utf8)
    }
}
