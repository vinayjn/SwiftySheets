// swift-tools-version:6.0
import PackageDescription

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
    ],
    dependencies: [
        .package(url: "https://github.com/googleapis/google-auth-library-swift.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "SwiftySheets",
            dependencies: [
                .product(name: "OAuth2", package: "google-auth-library-swift"),                
            ]
        ),
        .testTarget(
            name: "SwiftySheetsTests",
            dependencies: ["SwiftySheets"]
        ),
    ]
)
