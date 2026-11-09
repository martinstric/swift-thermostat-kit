//
//  FakeServer.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Foundation
import Synchronization
@testable import ThermostatKit

final class FakeServer: HTTPTransport {
    
    struct State {
        var password = Credentials.valid.password
        var statusBody: Data
        var loginDelay: Duration = .zero
        var isSessionValid = false
        var loginAttempts = 0
        var resetCount = 0
        var requests: [URLRequest] = []
        var thermostatPage: (status: Int, location: String?, body: Data) =
            (302, "https://thermostat.uniluxvfc.com/my-thermostat/\(testUUID)/", Data())
    }
    
    private let state: Mutex<State>
    
    init() throws {
        state = Mutex(State(statusBody: try fixture("status")))
    }
    
    // MARK: Test Controls
    
    func configure(_ change: (inout State) -> Void) {
        state.withLock { change(&$0) }
    }
    
    func expireSession() {
        configure { $0.isSessionValid = false }
    }
    
    var loginAttempts: Int { state.withLock { $0.loginAttempts } }
    var resetCount: Int { state.withLock { $0.resetCount } }
    var requests: [URLRequest] { state.withLock { $0.requests } }
    
    func requests(to path: String) -> [URLRequest] {
        requests.filter { $0.url?.path().contains(path) == true }
    }
    
    // MARK: HTTPTransport
    
    func send(_ request: URLRequest) async throws(ThermostatError) -> (Data, HTTPURLResponse) {
        let path = request.url?.path() ?? ""
        let isLogin = path.hasSuffix("wp-login.php") && request.httpMethod == "POST"
        
        let delay = state.withLock { state in
            state.requests.append(request)
            return state.loginDelay
        }
        
        if isLogin, delay > .zero { try? await Task.sleep(for: delay) }
        
        let (status, location, body): (Int, String?, Data) = state.withLock { state in
            if path.hasSuffix("wp-login.php") {
                guard isLogin else { return (200, nil, Data()) } // cookie-priming GET
                state.loginAttempts += 1
                
                guard formFields(request.httpBody)["pwd"] == state.password else {
                    return (302, Self.loginURL, Data())
                }
                state.isSessionValid = true
                
                return (302, Self.thermostatURL, Data())
            }
            
            if path.hasSuffix("/my-thermostat/") {
                return state.thermostatPage
            }
            
            guard state.isSessionValid else { return (302, Self.loginURL, Data()) }
            
            if path.contains("get-data") { return (200, nil, state.statusBody) }
            if let match = path.wholeMatch(of: #/\/my-thermostat\/([^\/]+)/#) {
                return (302, "/my-thermostat/uuid/\(match.1)/", Data())
            }
            if path.contains("/my-thermostat/uuid/"), path.hasSuffix("/") {
                let page = path.contains(testUUID)
                    ? #"<script>const url = "/my-thermostat/set-online-config/\#(testDeviceID)";</script>"#
                    : "<p>Thermostat</p>"
                return (200, nil, Data(page.utf8))
            }
            if path.contains("set-online-config") { return (200, nil, Data()) }
            
            return (404, nil, Data())
        }
        
        let headers = location.map { ["Location": $0] } ?? [:]
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: "HTTP/1.1", headerFields: headers)!
        return (body, response)
    }
    
    func resetSession() async {
        configure {
            $0.isSessionValid = false
            $0.resetCount += 1
        }
    }
    
    private static let loginURL = "https://thermostat.uniluxvfc.com/wp-login.php"
    private static let thermostatURL = "https://thermostat.uniluxvfc.com/my-thermostat/"
}
