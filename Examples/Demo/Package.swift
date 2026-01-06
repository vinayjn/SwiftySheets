// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SwiftySheetsDemo",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../../"), // Local SwiftySheets dependency
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftySheetsDemo",
            dependencies: [
                .product(name: "SwiftySheets", package: "SwiftySheets"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Rainbow",
                "SwiftyTextTable"
            ]
        ),
    ]
)
