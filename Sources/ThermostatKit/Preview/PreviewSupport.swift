//
//  PreviewSupport.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation

public struct PreviewThermostat: Sendable {
    
    public var id: String
    public var configuration: ThermostatConfiguration
    public var currentTemperature: Temperature
    public var humidity: Double?
    public var failingStatusCode: Int?
    
    public init(
        id: String = PreviewThermostat.randomID(),
        configuration: ThermostatConfiguration = ThermostatConfiguration(
            mode: .heat,
            fan: .auto,
            holdMode: .permanent,
            setpoint: .celsius(22)),
        currentTemperature: Temperature = .celsius(21),
        humidity: Double? = 0.45,
        failingStatusCode: Int? = nil
    ) {
        self.id = id
        self.configuration = configuration
        self.currentTemperature = currentTemperature
        self.humidity = humidity
        self.failingStatusCode = failingStatusCode
    }
    
    /// A unique 32-character hex ID, the same shape as real device IDs, so discovery finds it.
    public static func randomID() -> String {
        UUID().uuidString.replacing("-", with: "").lowercased()
    }
}

extension UniluxAccount {
    
    /// A signed-in account backed by fake thermostats. For SwiftUI Previews.
    ///
    /// Commands update the fake thermostat, so controls behave like the real thing,
    /// including debouncing and `confirm(_:)`.
    public static func preview(
        _ thermostats: [PreviewThermostat] = [PreviewThermostat()],
        latency: Duration = .milliseconds(300)
    ) -> UniluxAccount {
        UniluxAccount(
            store: InMemoryCredentialStore(
                Credentials(username: "preview@example.com", password: "preview")),
            transport: PreviewTransport(thermostats: thermostats, latency: latency)
        )
    }
}

extension Thermostat {
    
    /// A single fake thermostat, for previewing a detail view without going through discovery.
    public static func preview(
        _ thermostat: PreviewThermostat = PreviewThermostat(),
        latency: Duration = .milliseconds(300)
    ) -> Thermostat {
        UniluxAccount
            .preview([thermostat], latency: latency)
            .thermostat(id: thermostat.id)
    }
}
