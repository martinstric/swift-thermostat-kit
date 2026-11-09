//
//  ThermostatTests.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation
import Testing
@testable import ThermostatKit

@Suite struct ThermostatTests {
    
    let server: FakeServer
    let account: UniluxAccount

    init() throws {
        server = try FakeServer()
        account = UniluxAccount(store: InMemoryCredentialStore(.valid), transport: server)
    }

    var thermostat: Thermostat { account.thermostat(id: testUUID) }

    @Test func updateSendsCurrentConfigurationWithTheChange() async throws {
        let sent = try await thermostat.update { $0.setpoint = .celsius(22) }

        #expect(sent.setpoint == .celsius(22))
        #expect(sent.mode == .heat)  // untouched fields come from the fetched status

        let request = try #require(server.requests(to: "set-online-config").last)
        let data = try #require(try commandJSON(request.httpBody)["data"] as? NSDictionary)
        #expect(data["temp"] as? Double == 22)
        #expect(data["mode"] as? String == "heat")
        #expect(data["temp_mode"] as? String == "hold")
    }

    @Test func invalidConfigurationIsRejectedBeforeSending() async {
        let configuration = ThermostatConfiguration(mode: .heat, fan: .auto, holdMode: .permanent,
                                                    setpoint: .celsius(50))
        let error = await #expect(throws: ThermostatError.self) { try await thermostat.apply(configuration) }

        #expect(error?.isInvalidConfiguration == true)
        #expect(server.requests.isEmpty)
    }

    @Test func malformedStatusThrowsDecodingFailed() async {
        server.configure { $0.statusBody = Data("{}".utf8) }
        let error = await #expect(throws: ThermostatError.self) { try await thermostat.status() }

        #expect(error?.isDecodingFailed == true)
    }
    
    @Test func commandsUseShortDeviceIDFetchedOnce() async throws {
        try await thermostat.update { $0.setpoint = .celsius(22) }
        try await thermostat.update { $0.setpoint = .celsius(23) }

        let commands = server.requests(to: "set-online-config")
        #expect(commands.count == 2)
        #expect(commands.allSatisfy { $0.url?.lastPathComponent == testDeviceID })
        #expect(try commandJSON(commands[0].httpBody)["device_id"] as? String == testDeviceID)

        let pageLoads = server.requests.filter { $0.url?.path().hasSuffix("/uuid/\(testUUID)/") == true }
        #expect(pageLoads.count == 1)  // cached
    }

    @Test func missingDeviceIDThrows() async {
        let other = account.thermostat(id: "no-such-thermostat")
        let configuration = ThermostatConfiguration(mode: .heat, fan: .auto, holdMode: .permanent,
                                                    setpoint: .celsius(21))
        let error = await #expect(throws: ThermostatError.self) { try await other.apply(configuration) }
        #expect(error?.isDeviceIDNotFound == true)
    }
}
