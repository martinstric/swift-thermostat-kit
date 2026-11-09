//
//  TestHelpers.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation
import Testing
@testable import ThermostatKit

let testUUID = "0123456789abcdef0123456789abcdef"
let testDeviceID = "a1b2c3d4e5f6"

extension Credentials {
    
    static let valid = Credentials(username: "user@example.com", password: "password")
}

extension Date {
    
    static let fixed = Date(timeIntervalSince1970: 1_792_350_000)
}

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

func jsonObject(_ string: String) throws -> NSDictionary {
    let object = try JSONSerialization.jsonObject(with: Data(string.utf8))
    return try #require(object as? NSDictionary)
}

/// Decodes a set-online-config body: base64 -> JSON object.
func commandJSON(_ body: Data?) throws -> NSDictionary {
    let body = try #require(body)
    let json = try #require(Data(base64Encoded: body))
    let object = try JSONSerialization.jsonObject(with: json)
    return try #require(object as? NSDictionary)
}

func formFields(_ body: Data?) -> [String: String] {
    let string = String(decoding: body ?? Data(), as: UTF8.self)
    let pairs = string.split(separator: "&").compactMap { pair -> (String, String)? in
        let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]).removingPercentEncoding ?? "", String(parts[1]).removingPercentEncoding ?? "")
    }
    
    return Dictionary(pairs, uniquingKeysWith: { $1 })
}

func isApproximately(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

/// ThermostatError isn't Equatable, so match cases instead
extension ThermostatError {
    
    var isLoginFailed: Bool { if case .loginFailed = self { true } else { false } }
    var isMissingCredentials: Bool { if case .missingCredentials = self { true } else { false } }
    var isInvalidConfiguration: Bool { if case .invalidConfiguration = self { true } else { false } }
    var isDecodingFailed: Bool { if case .decodingFailed = self { true } else { false } }
    var isDeviceIDNotFound: Bool { if case .deviceIDNotFound = self { true } else { false } }
}
