//
//  HTTPTransport.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws(ThermostatError) -> (Data, HTTPURLResponse)
    func resetSession() async
}

extension URLSession: HTTPTransport {
    
    func send(_ request: URLRequest) async throws(ThermostatError) -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await self.data(for: request)
        } catch let error as URLError {
            throw .transport(error)
        } catch {
            fatalError("Unknown error occurred")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else { throw .badResponse }
        return (data, httpResponse)
    }
    
    func resetSession() async {
        await reset()
    }
}

extension URLSession {
    
    static func thermostat() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        return URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }
}
