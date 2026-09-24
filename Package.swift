// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Daymark",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Daymark", targets: ["Daymark"])
    ],
    targets: [
        .executableTarget(name: "Daymark"),
        .testTarget(name: "DaymarkTests", dependencies: ["Daymark"])
    ]
)
