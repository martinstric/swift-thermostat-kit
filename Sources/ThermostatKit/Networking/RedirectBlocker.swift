//
//  RedirectBlocker.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation

final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
