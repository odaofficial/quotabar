// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "QuotaBarCore", targets: ["QuotaBarCore"]),
        .executable(name: "QuotaBar", targets: ["QuotaBar"])
    ],
    targets: [
        .target(name: "QuotaBarCore", linkerSettings: [.linkedFramework("Security"), .linkedLibrary("sqlite3")]),
        .executableTarget(name: "QuotaBar", dependencies: ["QuotaBarCore"], resources: [.copy("Resources")], linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]),
        .testTarget(name: "QuotaBarCoreTests", dependencies: ["QuotaBarCore"])
    ]
)
