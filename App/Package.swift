// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BiokineticsDosimetryApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AppDomain",         targets: ["AppDomain"]),
        .library(name: "App.Core",          targets: ["AppCore"]),
        .library(name: "EditorFeature",     targets: ["EditorFeature"]),
        .library(name: "CalculatorFeature", targets: ["CalculatorFeature"]),
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/SwiftRex/SwiftRex.git", branch: "main"),
        .package(url: "https://github.com/luizmb/FP.git", from: "1.8.1"),
        .package(url: "https://github.com/luizmb/NetworkTools.git", from: "0.5.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [

        // MARK: - Shared visual + domain types used by all feature targets

        .target(
            name: "AppDomain",
            dependencies: [
                .product(name: "Domain", package: "BiokineticsDosimetry"),
            ]
        ),

        // MARK: - Feature targets

        .target(
            name: "EditorFeature",
            dependencies: [
                "AppDomain",
                .product(name: "Domain",                  package: "BiokineticsDosimetry"),
                .product(name: "SwiftRex",                package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture",   package: "SwiftRex"),
                .product(name: "SwiftRex.Concurrency",    package: "SwiftRex"),
            ]
        ),

        .target(
            name: "CalculatorFeature",
            dependencies: [
                "AppDomain",
                .product(name: "Domain",                  package: "BiokineticsDosimetry"),
                .product(name: "Solver",                  package: "BiokineticsDosimetry"),
                .product(name: "SwiftRex",                package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture",   package: "SwiftRex"),
                .product(name: "SwiftRex.Concurrency",    package: "SwiftRex"),
            ]
        ),

        // MARK: - App core (wires features + navigation + home)

        .target(
            name: "AppCore",
            dependencies: [
                "AppDomain",
                "EditorFeature",
                "CalculatorFeature",
                .product(
                    name: "Domain",
                    package: "BiokineticsDosimetry"
                ),
                .product(
                    name: "Solver",
                    package: "BiokineticsDosimetry"
                ),
                .product(
                    name: "Parser",
                    package: "BiokineticsDosimetry"
                ),
                .product(
                    name: "SwiftRex",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Architecture",
                    package: "SwiftRex"
                ),
                .product(
                    name: "FP",
                    package: "FP"
                ),
                .product(
                    name: "Core",
                    package: "NetworkTools"
                ),
                .product(
                    name: "XMLCoder",
                    package: "XMLCoder"
                ),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "EditorFeatureTests",
            dependencies: [
                "EditorFeature",
                .product(
                    name: "SwiftRex",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Architecture",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Testing",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SnapshotTesting",
                    package: "swift-snapshot-testing"
                ),
            ]
        ),
        .testTarget(
            name: "CalculatorFeatureTests",
            dependencies: [
                "CalculatorFeature",
                .product(
                    name: "SwiftRex",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Architecture",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Testing",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SnapshotTesting",
                    package: "swift-snapshot-testing"
                ),
            ]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: [
                "AppCore",
                "EditorFeature",
                "CalculatorFeature",
                .product(
                    name: "SwiftRex",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Architecture",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SwiftRex.Testing",
                    package: "SwiftRex"
                ),
                .product(
                    name: "SnapshotTesting",
                    package: "swift-snapshot-testing"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
