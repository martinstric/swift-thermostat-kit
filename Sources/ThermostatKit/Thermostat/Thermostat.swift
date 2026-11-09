//
//  Thermostat.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

import Foundation

public struct Thermostat: Sendable, Identifiable {
    
    public let id: String
    let account: UniluxAccount
    
    init(id: String, account: UniluxAccount) {
        self.id = id
        self.account = account
    }
    
    // MARK: Reading
    
    public func settings() async throws(ThermostatError) -> ThermostatSettings {
        let (data, response) = try await account.perform(Endpoint.settings(uuid: id).request)
        try Self.validate(response)
        
        do {
            let wire = try JSONDecoder().decode(SettingsResponse.self, from: data)
            return try ThermostatSettings(wire)
        } catch {
            throw .decodingFailed(error)
        }
    }
    
    public func status() async throws(ThermostatError) -> ThermostatStatus {
        let (data, response) = try await account.perform(Endpoint.status(uuid: id).request)
        try Self.validate(response)
        
        do {
            let wire = try JSONDecoder().decode(StatusResponse.self, from: data)
            return try ThermostatStatus(wire)
        } catch {
            throw .decodingFailed(error)
        }
    }
    
    // MARK: Writing
    
    /// Sends a complete configuration. Prefer `update(_:)` unless you already hold one,
    /// for example from a previous status.
    public func apply(_ configuration: ThermostatConfiguration) async throws(ThermostatError) {
        try configuration.validate()
        let deviceID = try await account.deviceID(for: id)
        
        let payload = CommandPayload(configuration: configuration, deviceID: deviceID, date: .now)
        let json: Data
        do {
            json = try JSONEncoder().encode(payload)
        } catch {
            throw .encodingFailed(error)
        }
        
        let request = Endpoint.setConfiguration(deviceID: deviceID, payload: json).request
        let (_, response) = try await account.perform(request)
        try Self.validate(response)
    }
    
    /// Fetches the current configuration, applies `change`, and sends the result.
    ///
    ///     try await thermostat.update { $0.setpoint = .celsius(21) }
    ///
    /// - Returns: The configuration that was sent, for optimistic UI or `confirm(_:)`.
    @discardableResult
    public func update(
        _ change: (inout ThermostatConfiguration) -> Void
    ) async throws(ThermostatError) -> ThermostatConfiguration {
        var configuration = try await status().configuration
        change(&configuration)
        try await apply(configuration)
        return configuration
    }
    
    // MARK: Confirming
    
    /// Polls until the thermostat reports `configuration`.
    ///
    ///     let sent = try await thermostat.update { $0.setpoint = target }
    ///     if let confirmed = try await thermostat.confirm(sent) { status = confirmed }
    ///
    /// - Returns: The first matching status, or `nil` if `timeout` passes or the task is cancelled.
    @discardableResult
    public func confirm(
        _ configuration: ThermostatConfiguration,
        every interval: Duration = .seconds(3),
        timeout: Duration = .seconds(30)
    ) async throws(ThermostatError) -> ThermostatStatus? {
        let deadline = ContinuousClock.now + timeout
        
        while ContinuousClock.now < deadline {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return nil // cancelled, e.g. the view disappeared
            }
            
            let status = try await status()
            if status.configuration.matches(configuration) { return status }
        }
        
        return nil
    }
    
    // MARK: Private
    
    private static func validate(_ response: HTTPURLResponse) throws(ThermostatError) {
        guard (200...299).contains(response.statusCode) else {
            throw .unexpectedStatus(response.statusCode)
        }
    }
}

// MARK: - Hashable -

extension Thermostat: Hashable {
    
    public static func == (lhs: Thermostat, rhs: Thermostat) -> Bool {
        lhs.id == rhs.id && lhs.account.id == rhs.account.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(ObjectIdentifier(account))
    }
}

// MARK: - Matching -

private extension ThermostatConfiguration {
    
    /// Compares only what's sent to the server. `setpointRange` is reported, not set,
    /// and the setpoint is compared after the same rounding the wire applies.
    func matches(_ other: ThermostatConfiguration) -> Bool {
        mode == other.mode
        && fan == other.fan
        && holdMode == other.holdMode
        && setpoint.wireValue == other.setpoint.wireValue
    }
}
