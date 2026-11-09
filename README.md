# ThermostatKit

An unofficial Swift package for controlling **Unilux Universe** thermostats on iOS, watchOS and macOS.

ThermostatKit talks to the same web service as the official Unilux app and website. It handles sign-in, session renewal, thermostat discovery, reading status and changing settings, behind a small async/await API.

> **Not affiliated with Unilux.** This package uses an undocumented web API that can change without notice. Use it at your own risk.

## Features

- Sign in once and store credentials in the Keychain. Expired sessions renew silently.
- Discover the thermostats on an account, whether it has none, one or several.
- Read current temperature, humidity, mode, fan, hold mode, setpoint and the device's setpoint limits.
- Change settings with a single call that fetches, modifies and sends the full configuration.
- Confirm that a change was applied by polling until the thermostat reports it.
- Typed throws throughout, so every failure is a `ThermostatError` you can switch over.
- A built-in fake server for SwiftUI previews that runs the real request and decoding code.

## Requirements

- Swift 6.2
- iOS 26, watchOS 26 or macOS 26

## Installation

Add the package in Xcode with **File → Add Package Dependencies…**, or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/martinstric/swift-thermostat-kit.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "ThermostatKit", package: "swift-thermostat-kit"),
    ]),
]
```

## Usage

### Sign in

Create one `UniluxAccount` for your whole app. By default it stores credentials in the Keychain.

```swift
import ThermostatKit

let account = UniluxAccount()

try await account.signIn(username: "you@example.com", password: "…")
```

Credentials are saved only after the server accepts them, so a mistyped password is never stored. On later launches, check whether you're already signed in:

```swift
if try await account.storedUsername() != nil {
    // Signed in. The first request will sign in silently.
}
```

### Find your thermostats

```swift
let thermostats = try await account.thermostats()
```

An account with no thermostats returns an empty array rather than throwing. If you already know a thermostat's ID, you can skip discovery:

```swift
let thermostat = account.thermostat(id: "850e22b8220ba13b0e27bfd56f3e7038")
```

### Read status

```swift
let status = try await thermostat.status()

status.currentTemperature   // Temperature
status.humidity             // Double? in 0...1
status.mode                 // .heat, .cool, .auto, .off
status.fan                  // .auto, .low, .medium, .high, .off
status.holdMode             // .schedule, .temporary, .permanent
status.setpoint             // Temperature
status.setpointRange        // ClosedRange<Temperature>, reported by the device
status.lastSeen             // When the thermostat last checked in
```

Configuration properties such as `mode` and `setpoint` are forwarded from `status.configuration`, so you can read them directly from the status.

### Change settings

The server expects a complete configuration on every change. `update(_:)` fetches the current one, applies your change and sends the result:

```swift
let sent = try await thermostat.update { $0.setpoint = .celsius(21) }
```

Configurations are validated against the device's limits before anything is sent. If you already hold a configuration, send it with `apply(_:)`.

### Confirm a change

Commands are accepted by the server immediately, but the thermostat picks them up on its own schedule. `confirm(_:)` polls until the reported status matches what you sent:

```swift
if let confirmed = try await thermostat.confirm(sent) {
    // The thermostat reports the new configuration.
}
```

It returns `nil` if the timeout passes (30 seconds by default) or the task is cancelled.

### Temperatures

`Temperature` stores Celsius and converts on demand. For display, use its `Measurement`, which respects the user's unit preference:

```swift
let target = Temperature.fahrenheit(70)
target.celsius                  // 21.1…

Text(status.setpoint.measurement, format: .measurement(width: .narrow))
```

### Sign out

```swift
try await account.signOut()
```

This clears the session and deletes the stored credentials.

## Handling errors

Every throwing call throws `ThermostatError`, which conforms to `LocalizedError`, so `localizedDescription` is ready to show in your UI. A few cases deserve special handling:

| Error | Meaning |
|---|---|
| `.missingCredentials` | Nothing is stored. Show your sign-in screen. |
| `.loginFailed` | The stored password was rejected, usually because it was changed. Ask the user to sign in again. |
| `.invalidConfiguration` | A setting is outside the device's limits. Nothing was sent. |
| `.transport(URLError)` | A network failure. Check `code == .cancelled` before showing it, since cancellation isn't a failure. |

Failed silent sign-ins aren't retried, because repeated failed logins can trigger the site's account lockout.

## Credential storage

`KeychainCredentialStore` saves the username and password as a generic password item that is available after first unlock and never leaves the device. That lets widgets and background refresh work while the device is locked.

To share credentials with an app extension such as a widget, pass a Keychain access group:

```swift
let account = UniluxAccount(store: KeychainCredentialStore(accessGroup: "TEAMID.com.example.shared"))
```

For tests or custom storage, conform to `CredentialStore`. `InMemoryCredentialStore` is included.

### watchOS

The Keychain isn't shared between iPhone and Apple Watch. For a companion watch app, send the credentials from the phone with WatchConnectivity and save them on the watch with `KeychainCredentialStore`. The watch then talks to the server directly, so it works even when the phone isn't nearby. This handoff belongs in your app; ThermostatKit doesn't depend on WatchConnectivity.

## SwiftUI previews

`UniluxAccount.preview(_:latency:)` returns a signed-in account backed by an in-memory fake server. Requests go through the real sign-in, discovery, decoding and command code, and commands update the fake thermostat, so controls behave as they do against the real service.

```swift
#Preview {
    ThermostatDetailView(thermostat: .preview())
}

#Preview("Cooling") {
    ThermostatDetailView(thermostat: .preview(PreviewThermostat(
        configuration: ThermostatConfiguration(mode: .cool, fan: .high, holdMode: .permanent,
                                               setpoint: .celsius(23)),
        currentTemperature: .celsius(26)
    )))
}

#Preview("Server error") {
    ThermostatDetailView(thermostat: .preview(PreviewThermostat(failingStatusCode: 500)))
}
```

Pass several `PreviewThermostat`s to `UniluxAccount.preview(_:)` to preview multi-thermostat layouts, or an empty array to preview an account with none.

## Known limitations

- **Heating and cooling activity isn't reported yet.** The status response doesn't have an obvious flag for whether the system is currently running.
- **Schedules and vacation mode aren't modelled.** In schedule mode, `setpoint` reflects the hold temperature, not the active schedule program.
- **Fahrenheit thermostats are untested.** Status is read in whichever scale the thermostat uses, but commands are sent in Celsius.
- **Accounts with several thermostats are untested.** Discovery handles them, but hasn't been tried against a real account.

Contributions with captured responses from other setups are very welcome. Please redact device IDs and personal details.

## Testing

```sh
swift test
```

The test suite runs against a fake server and never touches the real service. It covers sign-in, silent session renewal, concurrent requests sharing one sign-in, discovery, status decoding (including the server's inconsistent number types), and command encoding.

## License

ThermostatKit is available under the MIT license. See [LICENSE](LICENSE) for details.
