// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "BiokineticsDosimetry",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Solver", targets: ["Solver"]),
        .library(name: "Parser", targets: ["Parser"]),
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.8.1"),
        .package(url: "https://github.com/luizmb/NetworkTools.git", from: "0.5.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0"),
        .package(url: "https://github.com/luizmb/SwiftCalx.git", from: "0.3.0")
    ],
    targets: [
        // Pure value types — lingua franca for all other targets.
        .target(
            name: "Domain",
            dependencies: [
                .product(name: "FP", package: "FP"),
                .product(name: "FPMacros", package: "FP"),
            ]
        ),

        // All math and computation. Extends Domain types; returns DeferredTask/Result.
        .target(
            name: "Solver",
            dependencies: [
                "Domain",
                .product(name: "CoreFP", package: "FP"),
                .product(name: "Math", package: "SwiftCalx"),
                .product(name: "Calculus", package: "SwiftCalx"),
                .product(name: "RungeKutta", package: "SwiftCalx"),
            ]
        ),

        // File I/O: converts data formats into Domain types.
        .target(
            name: "Parser",
            dependencies: [
                "Domain",
                .product(name: "FP", package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
                .product(name: "XMLCoder", package: "XMLCoder"),
            ]
        ),

        .testTarget(
            name: "BiokineticsDosimetryTests",
            dependencies: ["Domain", "Solver", "Parser"],
            resources: [.process("Fixtures")]
        )
    ]
)
