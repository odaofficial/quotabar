// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OdaLimits",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OdaLimitsCore", targets: ["OdaLimitsCore"]),
        .executable(name: "OdaLimits", targets: ["OdaLimits"])
    ],
    targets: [
        .target(name: "OdaLimitsCore", linkerSettings: [.linkedFramework("Security"), .linkedLibrary("sqlite3")]),
        .executableTarget(name: "OdaLimits", dependencies: ["OdaLimitsCore"], linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]),
        .testTarget(name: "OdaLimitsCoreTests", dependencies: ["OdaLimitsCore"])
    ]
)
