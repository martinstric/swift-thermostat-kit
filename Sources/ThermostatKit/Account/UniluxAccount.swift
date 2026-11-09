//
//  UniluxAccount.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-18.
//

import Foundation
import os

public actor UniluxAccount {
    
    private static let signedInPaths = ["my-thermostat", "my-dashboard"]
    
    /// Stable identity for Hashable conformances. `nonisolated` so it's readable without `await`.
    nonisolated let id = UUID()
    
    private let store: any CredentialStore
    private let transport: any HTTPTransport
    private let logger = Logger(subsystem: "ThermostatKit", category: "Account")
    
    private var isAuthenticated = false
    private var signInTask: Task<Result<Void, ThermostatError>, Never>?
    
    private var discoveredThermostats: [Thermostat]?
    private var deviceIDs: [String: String] = [:]
    
    public init(store: any CredentialStore = KeychainCredentialStore()) {
        self.init(store: store, transport: URLSession.thermostat())
    }
    
    init(store: any CredentialStore, transport: any HTTPTransport) {
        self.store = store
        self.transport = transport
    }
    
    // MARK: Public
    
    /// For a "Signed in as ..." row, or deciding whether to show the sign-in screen.
    public func storedUsername() throws(ThermostatError) -> String? {
        try withStore { () throws(CredentialStoreError) in try store.load() }?.username
    }
    
    /// Interactive sign-in. Credentials are only persisted once the server accepts them.
    public func signIn(username: String, password: String) async throws(ThermostatError) {
        let credentials = Credentials(username: username, password: password)
        try await authenticate(with: credentials)
        isAuthenticated = true
        try withStore { () throws(CredentialStoreError) in try store.save(credentials) }
    }
    
    public func signOut() async throws(ThermostatError) {
        signInTask?.cancel()
        signInTask = nil
        isAuthenticated = false
        discoveredThermostats = nil
        deviceIDs = [:]
        await transport.resetSession()
        
        try withStore { () throws(CredentialStoreError) in try store.delete() }
    }
    
    public func thermostats() async throws(ThermostatError) -> [Thermostat] {
        if let discoveredThermostats { return discoveredThermostats }
        
        let (data, response) = try await perform(Endpoint.thermostatPage.request)
        guard (200..<400).contains(response.statusCode) else {
            throw .unexpectedStatus(response.statusCode)
        }
        
        let location = response.value(forHTTPHeaderField: "Location") ?? ""
        let page = String(decoding: data, as: UTF8.self)
        let thermostats = Self.deviceIDs(in: location + "\n" + page).map { id in
            thermostat(id: id)
        }
        
        // Don't cache an empty result, so a newly added thermostat shows up on the next call
        if !thermostats.isEmpty { discoveredThermostats = thermostats }
        return thermostats
    }
    
    nonisolated public func thermostat(id: String) -> Thermostat {
        Thermostat(id: id, account: self)
    }
    
    // MARK: Internal
    
    func perform(_ request: URLRequest) async throws(ThermostatError) -> (Data, HTTPURLResponse) {
        try await ensureSignedIn()
        
        do throws(ThermostatError) {
            return try await sendAuthenticated(request)
        } catch .notAuthenticated {
            logger.info("Session expired, signing in again")
            isAuthenticated = false
            try await ensureSignedIn()
            return try await sendAuthenticated(request) // retry exactly once
        }
    }
    
    func deviceID(for uuid: String) async throws(ThermostatError) -> String {
        if let cached = deviceIDs[uuid] { return cached }
        
        let (data, response) = try await followRedirects(from: Endpoint.thermostatEntry(uuid: uuid).request)
        guard (200..<300).contains(response.statusCode) else {
            throw .unexpectedStatus(response.statusCode)
        }
        
        let page = String(decoding: data, as: UTF8.self)
        guard let match = page.firstMatch(of: #/set-online-config/([0-9a-fA-F]{12})/#) else {
            logger.debug("No device ID on thermostat page \(uuid, privacy: .public)")
            throw .deviceIDNotFound
        }
        
        let deviceID = String(match.1)
        deviceIDs[uuid] = deviceID
        return deviceID
    }
    
    // MARK: Private
    
    /// Signs in with stored credentials if needed. Concurrect callers share one login.
    private func ensureSignedIn() async throws(ThermostatError) {
        guard !isAuthenticated else { return }
        
        let task: Task<Result<Void, ThermostatError>, Never>
        if let signInTask {
            task = signInTask
        } else {
            guard let credentials = try withStore({ () throws(CredentialStoreError) in try store.load() }) else {
                throw .missingCredentials
            }
            
            task = Task {
                do throws(ThermostatError) {
                    try await authenticate(with: credentials)
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }
            
            signInTask = task
        }
        
        let result = await task.value
        if signInTask == task { signInTask = nil }
        try result.get()
        isAuthenticated = true
    }
    
    private func authenticate(with credentials: Credentials) async throws(ThermostatError) {
        // Prime the WordPress test cookie, like a browser loading the page first
        _ = try? await transport.send(Endpoint.loginPage.request)
        
        let (_, response) = try await transport.send(Endpoint.login(credentials).request)
        let location = response.value(forHTTPHeaderField: "Location") ?? ""
        guard response.statusCode == 302,
              Self.signedInPaths.contains(where: { location.contains($0) })
        else {
            logger.debug("Login rejected: \(response.statusCode, privacy: .public) location=\(location, privacy: .public)")
            throw .loginFailed
        }
    }
    
    private func sendAuthenticated(_ request: URLRequest) async throws(ThermostatError) -> (Data, HTTPURLResponse) {
        let (data, response) = try await transport.send(request)
        if response.statusCode == 302,
           response.value(forHTTPHeaderField: "Location")?.contains("wp-login.php") == true {
            throw .notAuthenticated
        }
        
        return (data, response)
    }
    
    private func withStore<T>(_ body: () throws(CredentialStoreError) -> T) throws(ThermostatError) -> T {
        do throws(CredentialStoreError) { return try body() }
        catch { throw .credentialStore(error) }
    }
    
    private static func deviceIDs(in text: String) -> [String] {
        var seen = Set<String>()
        return text
            .matches(of: #/my-thermostat/(?:uuid/)?([0-9a-fA-F]{32})/#)
            .map { String($0.1) }
            .filter { seen.insert($0).inserted }
    }
    
    private func followRedirects(
        from request: URLRequest,
        maxHops: Int = 5
    ) async throws(ThermostatError) -> (Data, HTTPURLResponse) {
        var request = request
        
        for _ in 0..<maxHops {
            let (data, response) = try await perform(request)
            guard (300..<400).contains(response.statusCode),
                  let location = response.value(forHTTPHeaderField: "Location"),
                  let next = URL(string: location, relativeTo: request.url)?.absoluteURL
            else { return (data, response) }

            logger.debug("Redirect \(response.statusCode, privacy: .public) → \(next.absoluteString, privacy: .public)")
            request = URLRequest(url: next)
            request.timeoutInterval = 15
        }
        
        throw .badResponse  // too many redirects
    }
}
