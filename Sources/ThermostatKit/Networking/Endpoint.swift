//
//  Endpoint.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-19.
//

import Foundation

enum Endpoint: Sendable {
    case loginPage
    case login(Credentials)
    case thermostatPage
    case thermostatEntry(uuid: String)
    case setConfiguration(deviceID: String, payload: Data)
    case status(uuid: String)
    case settings(uuid: String)
    
    static let baseURL = URL(string: "https://thermostat.uniluxvfc.com")!
    
    var request: URLRequest {
        switch self {
        case .loginPage:
            return Self.request(path: "wp-login.php")
            
        case .login(let credentials):
            return Self.formRequest(path: "wp-login.php", fields: [
                "log": credentials.username,
                "pwd": credentials.password,
                "rememberme": "forever",
                "wp-submit": "Log In",
                "redirect_to": "",
                "testcookie": "1",
            ])
            
        case .thermostatPage:
            return Self.request(path: "my-thermostat/")
            
        case .thermostatEntry(let uuid):
            return Self.request(path: "my-thermostat/\(uuid)")
            
        case .setConfiguration(let deviceID, let payload):
            var request = Self.request(path: "my-thermostat/set-online-config/\(deviceID)", method: "POST")
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.httpBody = payload.base64EncodedData()
            return request
            
        case .status(let uuid):
            var request = Self.request(path: "my-thermostat/uuid/\(uuid)/get-data")
            request.url?.append(queryItems: [
                URLQueryItem(name: uuid, value: nil), // renders as a bare "?<id>"
                URLQueryItem(name: "_", value: String(Int(Date.now.timeIntervalSince1970 * 1000)))
            ])
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            return request
            
        case .settings(let uuid):
            var request = Self.request(path: "my-thermostat/settings/\(uuid)/get-data")
            request.url?.append(queryItems: [
                URLQueryItem(name: "_", value: String(Int(Date.now.timeIntervalSince1970 * 1000)))
            ])
            request.setValue("XMPHttpRequest", forHTTPHeaderField: "X-Requested-With")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            return request
        }
    }
    
    // MARK: Builders
    
    private static func request(path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 15
        return request
    }
    
    private static func formRequest(path: String, fields: [String: String]) -> URLRequest {
        var request = request(path: path, method: "POST")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(
            fields.map({ "\($0.formEncoded)=\($1.formEncoded)" }).joined(separator: "&").utf8
        )
        
        return request
    }
}

private extension String {
    
    var formEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .formValueAllowed) ?? self
    }
}

private extension CharacterSet {
    
    static let formValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+")
        return set
    }()
}
