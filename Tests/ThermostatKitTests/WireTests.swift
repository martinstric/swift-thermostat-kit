//
//  WireTests.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation
import Testing
@testable import ThermostatKit

@Suite struct CommandPayloadTests {
    
    let configuration = ThermostatConfiguration(mode: .heat, fan: .auto, holdMode: .permanent, setpoint: .celsius(21))
    
    @Test func matchesKnownGoodJSON() throws {
        let payload = CommandPayload(configuration: configuration, deviceID: testDeviceID, date: .fixed)
        let actual = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? NSDictionary
        let expected = try jsonObject("""
            {"data": {"fan": "auto", "mode": "heat", "temp_mode": "hold", "temp": 21, "cool": 21},
             "device_id": "\(testDeviceID)", "datetime": 1792350000}
            """)
        
        #expect(actual == expected)
    }
    
    @Test func requestBodyIsBase64EncodedJSON() throws {
        let json = try JSONEncoder().encode(
            CommandPayload(configuration: configuration, deviceID: testDeviceID, date: .fixed)
        )
        let request = Endpoint.setConfiguration(deviceID: testDeviceID, payload: json).request
        
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/my-thermostat/set-online-config/\(testDeviceID)")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/plain")
        #expect(try commandJSON(request.httpBody) == JSONSerialization.jsonObject(with: json) as? NSDictionary)
    }
}
    
@Suite struct WireMappingTests {
    
    @Test func quirkyServerStrings() {
        #expect(FanMode.medium.wireValue == "med")
        #expect(HoldMode.temporary.wireValue == "temp")
        #expect(HoldMode.permanent.wireValue == "hold")
    }
    
    @Test(arguments: FanMode.allCases)
    func fanModeRoundTrips(_ mode: FanMode) throws {
        #expect(try FanMode(wireValue: mode.wireValue) == mode)
    }
    
    @Test(arguments: ThermostatMode.allCases)
    func thermostatModeRoundTrips(_ mode: ThermostatMode) throws {
        #expect(try ThermostatMode(wireValue: mode.wireValue) == mode)
    }
    
    @Test(arguments: HoldMode.allCases)
    func holdModeRoundTrips(_ mode: HoldMode) throws {
        #expect(try HoldMode(wireValue: mode.wireValue) == mode)
    }
    
    @Test func unknownValueThrows() {
        #expect(throws: WireError.self) { try FanMode(wireValue: "turbo") }
    }
}

@Suite struct EndpointTests {
    
    @Test func statusRequestMirrorsTheWebApp() throws {
        let request = Endpoint.status(uuid: testUUID).request
        let url = try #require(request.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        #expect(url.path() == "/my-thermostat/uuid/\(testUUID)/get-data")
        #expect(items.first == URLQueryItem(name: testUUID, value: nil))
        #expect(items.contains { $0.name == "_" && Int($0.value ?? "") != nil })
        #expect(request.value(forHTTPHeaderField: "X-Requested-With") == "XMLHttpRequest")
    }
    
    @Test func loginFormEncodesSpecialCharacters() throws {
        let credentials = Credentials(username: "martin@example.com", password: "p&ss=w+rd 1")
        let body = String(decoding: try #require(Endpoint.login(credentials).request.httpBody), as: UTF8.self)
        let pairs = Set(body.split(separator: "&").map(String.init))
        
        #expect(pairs.contains("pwd=p%26ss%3Dw%2Brd%201"))
        #expect(pairs.contains("rememberme=forever"))
        #expect(pairs.contains("testcookie=1"))
    }
}
