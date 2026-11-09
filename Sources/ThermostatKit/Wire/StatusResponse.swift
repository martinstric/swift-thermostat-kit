//
//  StatusResponse.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

import Foundation

struct StatusResponse: Decodable {
    
    struct Readings: Decodable {
        
        let temperature: LenientDouble
        let humidity: LenientDouble?
    }

    struct OnlineConfig: Decodable {
        
        let mode: String
        let fan: String
        let tempMode: String
        let holdTemp: ScaledValue

        enum CodingKeys: String, CodingKey {
            case mode, fan
            case tempMode = "temp_mode"
            case holdTemp = "hold_temp"
        }
    }

    struct OnlineSettings: Decodable {
        
        let units: LenientInt
        let minTemp: ScaledValue
        let maxTemp: ScaledValue

        enum CodingKeys: String, CodingKey {
            case units
            case minTemp = "min_temp"
            case maxTemp = "max_temp"
        }
    }

    let data: Readings
    let onlineConfig: OnlineConfig
    let onlineSettings: OnlineSettings
    let lastSeen: LenientInt?

    enum CodingKeys: String, CodingKey {
        case data
        case onlineConfig = "online_config"
        case onlineSettings = "online_settings"
        case lastSeen = "last_seen"
    }
}

extension TemperatureScale {
    
    // TODO: 0 = Celsius is confirmed by your response; 1 = Fahrenheit is an assumption.
    
    init(wireValue: Int) throws(WireError) {
        switch wireValue {
        case 0: self = .celsius
        case 1: self = .fahrenheit
        default: throw .unknownValue(field: "units", value: String(wireValue))
        }
    }
}

extension ThermostatStatus {
    
    init(_ wire: StatusResponse, fetchedAt: Date = .now) throws(WireError) {
        let scale = try TemperatureScale(wireValue: wire.onlineSettings.units.value)
        let config = wire.onlineConfig

        let lower = wire.onlineSettings.minTemp.temperature(in: scale)
        let upper = wire.onlineSettings.maxTemp.temperature(in: scale)
        guard lower <= upper else {
            throw .unknownValue(field: "min_temp/max_temp", value: "\(lower)–\(upper)")
        }

        self.init(
            configuration: ThermostatConfiguration(
                mode: try ThermostatMode(wireValue: config.mode),
                fan: try FanMode(wireValue: config.fan),
                holdMode: try HoldMode(wireValue: config.tempMode),
                setpoint: config.holdTemp.temperature(in: scale),
                setpointRange: lower ... upper
            ),
            currentTemperature: Temperature(wire.data.temperature.value, in: scale),
            humidity: wire.data.humidity.map { $0.value / 100 },
            scale: scale,
            lastSeen: wire.lastSeen.map { fetchedAt.addingTimeInterval(-Double($0.value)) },  // TODO: assumed seconds
            updatedAt: fetchedAt
        )
    }
}
