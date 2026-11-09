//
//  WireSupport.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

struct Lenient<Value: Decodable & LosslessStringConvertible>: Decodable {
    
    let value: Value

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Value.self) {
            self.value = value
            return
        }
        
        let string = try container.decode(String.self)
        guard let value = Value(string.trimmingCharacters(in: .whitespaces)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected \(Value.self), got \"\(string)\"")
        }
        self.value = value
    }
}

typealias LenientDouble = Lenient<Double>
typealias LenientInt = Lenient<Int>

struct ScaledValue: Decodable {
    
    let celsius: LenientDouble
    let fahrenheit: LenientDouble

    func temperature(in scale: TemperatureScale) -> Temperature {
        switch scale {
        case .celsius: Temperature(celsius.value, in: .celsius)
        case .fahrenheit: Temperature(fahrenheit.value, in: .fahrenheit)
        }
    }
}
