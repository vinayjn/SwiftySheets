// swift-tools-version:6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftySheets",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "SwiftySheets",
            targets: ["SwiftySheets"]
        ),
        .executable(
            name: "SwiftySheetsDemo",
            targets: ["SwiftySheetsDemo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/googleapis/google-auth-library-swift.git", from: "0.5.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
    ],
    targets: [
        // Core Library
        .target(
            name: "SwiftySheets",
            dependencies: [
                .product(name: "OAuth2", package: "google-auth-library-swift"),
                "SwiftySheetsMacros"
            ]
        ),
        // Macros Implementation
        .macro(
            name: "SwiftySheetsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        // Tests
        .testTarget(
            name: "SwiftySheetsTests",
            dependencies: [
                "SwiftySheets",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        // Demo
        .executableTarget(
            name: "SwiftySheetsDemo",
            dependencies: ["SwiftySheets"]
        ),
    ]
)
