//
//  AccountTests.swift
//  ThermostatKit
//
//  Created by Martin Stric on 2026-10-20.
//

import Testing
import Foundation
@testable import ThermostatKit

@Suite struct AccountTests {
    
    let server: FakeServer
    let store: InMemoryCredentialStore
    let account: UniluxAccount

    init() throws {
        server = try FakeServer()
        store = InMemoryCredentialStore(.valid)
        account = UniluxAccount(store: store, transport: server)
    }

    var thermostat: Thermostat { account.thermostat(id: testUUID) }

    // MARK: Interactive sign-in

    @Test func signInSavesCredentialsOnSuccess() async throws {
        store.delete()
        try await account.signIn(username: Credentials.valid.username, password: Credentials.valid.password)

        #expect(store.load() == .valid)
        #expect(server.loginAttempts == 1)
    }

    @Test func signInWithWrongPasswordSavesNothing() async {
        store.delete()
        let error = await #expect(throws: ThermostatError.self) {
            try await account.signIn(username: Credentials.valid.username, password: "wrong")
        }

        #expect(error?.isLoginFailed == true)
        #expect(store.load() == nil)
    }

    @Test func signInPrimesCookieThenPostsForm() async throws {
        try await account.signIn(username: Credentials.valid.username, password: Credentials.valid.password)
        let requests = server.requests(to: "wp-login.php")

        #expect(requests.map(\.httpMethod) == ["GET", "POST"])
        let fields = formFields(requests.last?.httpBody)
        #expect(fields["log"] == Credentials.valid.username)
        #expect(fields["rememberme"] == "forever")
    }

    // MARK: Silent sign-in

    @Test func firstRequestSignsInWithStoredCredentials() async throws {
        _ = try await thermostat.status()
        #expect(server.loginAttempts == 1)
    }

    @Test func expiredSessionSignsInAgainAndRetries() async throws {
        _ = try await thermostat.status()
        server.expireSession()
        _ = try await thermostat.status()

        #expect(server.loginAttempts == 2)
        #expect(server.requests(to: "get-data").count == 3)  // ok, rejected, retried
    }

    @Test func concurrentRequestsShareOneSignIn() async throws {
        server.configure { $0.loginDelay = .milliseconds(100) }

        async let first = thermostat.status()
        async let second = thermostat.status()
        _ = try await (first, second)

        #expect(server.loginAttempts == 1)
    }

    @Test func missingCredentialsFailsWithoutTouchingTheNetwork() async {
        store.delete()
        let error = await #expect(throws: ThermostatError.self) { try await thermostat.status() }

        #expect(error?.isMissingCredentials == true)
        #expect(server.requests.isEmpty)
    }

    @Test func changedPasswordFailsOnceAndKeepsCredentials() async {
        server.configure { $0.password = "new-password" }
        let error = await #expect(throws: ThermostatError.self) { try await thermostat.status() }

        #expect(error?.isLoginFailed == true)
        #expect(server.loginAttempts == 1)  // no retry loop
        #expect(store.load() == .valid)
    }

    // MARK: Sign-out

    @Test func signOutClearsSessionAndCredentials() async throws {
        _ = try await thermostat.status()
        try await account.signOut()

        #expect(server.resetCount == 1)
        #expect(store.load() == nil)

        let error = await #expect(throws: ThermostatError.self) { try await thermostat.status() }
        #expect(error?.isMissingCredentials == true)
    }
    
    // MARK: Discovery
    
    @Test func singleThermostatComesFromRedirect() async throws {
        let thermostats = try await account.thermostats()
        _ = try await account.thermostats()

        #expect(thermostats.map(\.id) == [testUUID])
        #expect(server.requests(to: "my-thermostat/").count == 1)  // cached
    }

    @Test func multipleThermostatsComeFromListPage() async throws {
        let upstairs = String(repeating: "a", count: 32)
        let downstairs = String(repeating: "b", count: 32)
        server.configure {
            $0.thermostatPage = (200, nil, Data("""
                <a href="/my-thermostat/uuid/\(upstairs)/">Upstairs</a>
                <a href="/my-thermostat/uuid/\(downstairs)/">Downstairs</a>
                <form action="/my-thermostat/set-online-config/\(upstairs)">
                """.utf8))
        }
        
        let ids = try await account.thermostats().map(\.id)
        #expect(ids == [upstairs, downstairs])
    }

    @Test func noThermostatsReturnsEmptyAndIsNotCached() async throws {
        server.configure { $0.thermostatPage = (200, nil, Data("<p>Add a thermostat</p>".utf8)) }

        #expect(try await account.thermostats().isEmpty)
        _ = try await account.thermostats()
        #expect(server.requests(to: "my-thermostat/").count == 2)
    }
}
