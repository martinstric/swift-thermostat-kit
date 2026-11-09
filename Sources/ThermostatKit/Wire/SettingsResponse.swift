//
//  SettingsResponse.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation

struct SettingsResponse: Decodable {
    
    struct ThermoSettings: Decodable {
        
        let units: LenientInt
        let timeFormat: LenientInt
        let timeZone: LenientInt
        let timeZoneId: String
        let country: String
        let zip: String
        let minTemp: ScaledValue
        let maxTemp: ScaledValue
        
        enum CodingKeys: String, CodingKey {
            case units, country, zip
            case timeFormat = "time-format"
            case timeZone = "timezone"
            case timeZoneId = "timezoneId"
            case minTemp = "min_temp"
            case maxTemp = "max_temp"
        }
    }
    
    let name: String
    let settings: ThermoSettings
    let lastSeen: LenientInt
    
    enum CodingKeys: String, CodingKey {
        case name, settings
        case lastSeen = "last_seen"
    }
}

extension ThermostatSettings {
    
    init(_ wire: SettingsResponse, fetchedAt: Date = .now) throws(WireError) {
        self.init(
            name: wire.name,
            timeFormat: TimeFormat(rawValue: wire.settings.timeFormat.value) ?? .h24,
            timezoneOffset: wire.settings.timeZone.value,
            timezoneName: wire.settings.timeZoneId,
            updatedAt: fetchedAt
        )
    }
}
