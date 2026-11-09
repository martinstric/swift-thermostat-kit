// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThermostatKit",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(
            name: "ThermostatKit",
            targets: ["ThermostatKit"]
        ),
    ],
    targets: [
        .target(
            name: "ThermostatKit",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "ThermostatKitTests",
            dependencies: ["ThermostatKit"],
            resources: [.process("Fixtures")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
