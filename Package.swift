// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "FlexyMacV2",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FlexyMacV2",
            targets: ["FlexyMacV2"]
        )
    ],
    dependencies: [
        // Minizip for password-protected ZIP (V1 compatible)
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "FlexyMacV2",
            dependencies: ["Zip"],
            path: "FlexyMacV2"
        )
    ]
)
