//
//  CommandPayload.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

import Foundation

struct CommandPayload: Encodable {
    
    struct Settings: Encodable {
        let fan: String
        let mode: String
        let tempMode: String
        let temp: Double
        let cool: Double
        let vacationStart: [String: Double]?
        let vacationEnd: [String: Double]?

        enum CodingKeys: String, CodingKey {
            case fan, mode, temp, cool
            case tempMode = "temp_mode"
            case vacationStart = "vacation_start"
            case vacationEnd = "vacation_end"
        }
    }
    
    let data: Settings
    let deviceID: String
    let datetime: Int

    enum CodingKeys: String, CodingKey {
        case data, datetime
        case deviceID = "device_id"
    }
    
    init(configuration: ThermostatConfiguration, deviceID: String, date: Date) {
        data = Settings(
            fan: configuration.fan.wireValue,
            mode: configuration.mode.wireValue,
            tempMode: configuration.holdMode.wireValue,
            temp: configuration.setpoint.wireValue,
            cool: configuration.setpoint.wireValue,
            vacationStart: nil,
            vacationEnd: nil
        )
        
        self.deviceID = deviceID
        datetime = Int(date.timeIntervalSince1970)
    }
}
