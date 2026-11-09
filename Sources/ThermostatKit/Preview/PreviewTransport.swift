//
//  PreviewTransport.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation
import Synchronization

final class PreviewTransport: HTTPTransport {
    private let devices: Mutex<[String: PreviewThermostat]>
    private let deviceOrder: [String]
    private let latency: Duration

    init(thermostats: [PreviewThermostat], latency: Duration) {
        devices = Mutex(Dictionary(thermostats.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }))
        deviceOrder = thermostats.map(\.id)
        self.latency = latency
    }

    func send(_ request: URLRequest) async throws(ThermostatError) -> (Data, HTTPURLResponse) {
        try? await Task.sleep(for: latency)

        let url = request.url!
        let (status, location, body) = route(request, path: url.path())
        let headers = location.map { ["Location": $0] } ?? [:]
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (body, response)
    }

    func resetSession() async {}

    // MARK: Routes

    private func route(_ request: URLRequest, path: String) -> (Int, String?, Data) {
        if path.hasSuffix("wp-login.php") {
            return request.httpMethod == "POST" ? (302, "/my-thermostat/", Data()) : (200, nil, Data())
        }

        if path.hasSuffix("/my-thermostat/") {
            if deviceOrder.count == 1 { return (302, "/my-thermostat/\(deviceOrder[0])", Data()) }
            let links = deviceOrder.map { #"<a href="/my-thermostat/uuid/\#($0)/">Thermostat</a>"# }
            return (200, nil, Data(links.joined().utf8))
        }

        guard let id = deviceOrder.first(where: { path.contains($0) || path.contains(Self.shortID(for: $0)) }) else {
            return (404, nil, Data())
        }

        return devices.withLock { devices in
            guard var device = devices[id] else { return (404, nil, Data()) }
            if let code = device.failingStatusCode { return (code, nil, Data()) }
            
            if path.hasSuffix(id) {
                return (302, "/my-thermostat/uuid/\(id)/", Data())
            }

            if path.contains("settings"), path.hasSuffix("get-data") {
                return (200, nil, Self.settingsJSON(for: device))
            }
            
            if path.contains("uuid"), path.hasSuffix("get-data") {
                return (200, nil, Self.statusJSON(for: device))
            }
            
            if path.contains("/uuid/"), path.hasSuffix("/") {
                let page = #"<script>const url = "/my-thermostat/set-online-config/\#(Self.shortID(for: id))";</script>"#
                return (200, nil, Data(page.utf8))
            }
            
            if path.contains("set-online-config"), Self.apply(request.httpBody, to: &device) {
                devices[id] = device
                return (200, nil, Data())
            }
            
            return (400, nil, Data())
        }
    }

    // MARK: Wire format
    
    private static func shortID(for uuid: String) -> String {
        String(uuid.prefix(12))
    }
    
    private static func settingsJSON(for device: PreviewThermostat) -> Data {
        func scaled(_ temperature: Temperature) -> [String: Double] {
            ["celsius": temperature.celsius, "fahrenheit": temperature.fahrenheit]
        }

        let object: [String: Any] = [
            "name": "Preview Thermostat",
            "settings": [
                "units": 0,
                "time-format": 24,
                "timezone": -240,
                "timezoneId": "America/Toronto",
                "country": "CA",
                "zip": "Toronto",
                "min_temp": scaled(.celsius(10)),
                "max_temp": scaled(.celsius(40)),
            ],
            "last_seen": 4,
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func statusJSON(for device: PreviewThermostat) -> Data {
        let configuration = device.configuration
        func scaled(_ temperature: Temperature) -> [String: Double] {
            ["celsius": temperature.celsius, "fahrenheit": temperature.fahrenheit]
        }

        var readings: [String: Any] = ["temperature": device.currentTemperature.celsius]
        if let humidity = device.humidity { readings["humidity"] = humidity * 100 }

        let object: [String: Any] = [
            "data": readings,
            "online_config": [
                "mode": configuration.mode.wireValue,
                "fan": configuration.fan.wireValue,
                "temp_mode": configuration.holdMode.wireValue,
                "hold_temp": scaled(configuration.setpoint),
            ] as [String: Any],
            "online_settings": [
                "units": 0,
                "min_temp": scaled(configuration.setpointRange.lowerBound),
                "max_temp": scaled(configuration.setpointRange.upperBound),
            ] as [String: Any],
            "last_seen": 4,
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func apply(_ body: Data?, to device: inout PreviewThermostat) -> Bool {
        guard let body,
              let json = Data(base64Encoded: body),
              let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let data = object["data"] as? [String: Any],
              let mode = (data["mode"] as? String).flatMap({ try? ThermostatMode(wireValue: $0) }),
              let fan = (data["fan"] as? String).flatMap({ try? FanMode(wireValue: $0) }),
              let holdMode = (data["temp_mode"] as? String).flatMap({ try? HoldMode(wireValue: $0) }),
              let setpoint = data["temp"] as? Double
        else { return false }

        device.configuration.mode = mode
        device.configuration.fan = fan
        device.configuration.holdMode = holdMode
        device.configuration.setpoint = Temperature(wireValue: setpoint)
        return true
    }
}
