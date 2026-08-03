// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "BiokineticsDosimetryApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Style",              targets: ["Style"]),
        .library(name: "UIComponents",       targets: ["UIComponents"]),
        .library(name: "AppDomain",          targets: ["AppDomain"]),
        .library(name: "HomeFeature",        targets: ["HomeFeature"]),
        .library(name: "EditorFeature",      targets: ["EditorFeature"]),
        .library(name: "CalculatorFeature",  targets: ["CalculatorFeature"]),
        .library(name: "App.Core",           targets: ["AppCore"]),
    ],
    dependencies: [
        .package(name: "biokinetics-dosimetry", path: ".."),
        .package(url: "https://github.com/SwiftRex/SwiftRex.git", branch: "main", traits: ["ReactiveConcurrency"]),
        .package(url: "https://github.com/luizmb/ReactiveConcurrency.git", from: "1.1.0"),
        .package(url: "https://github.com/luizmb/FP.git", from: "2.2.0"),
        .package(url: "https://github.com/luizmb/NetworkTools.git", from: "0.8.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [

        // MARK: - Design system (previously a standalone DesignSystem package)

        .target(
            name: "Style",
            path: "Sources/Style"
        ),

        .target(
            name: "UIComponents",
            dependencies: ["Style"],
            path: "Sources/UIComponents"
        ),

        // MARK: - Shared visual + domain types used by all feature targets

        .target(
            name: "AppDomain",
            dependencies: [
                .product(name: "Domain",   package: "biokinetics-dosimetry"),
                .product(name: "FP",       package: "FP"),
                .product(name: "FPMacros", package: "FP"),
                "Style",
            ]
        ),

        // MARK: - Feature targets

        .target(
            name: "HomeFeature",
            dependencies: [
                "AppDomain",
                .product(name: "Domain",                package: "biokinetics-dosimetry"),
                .product(name: "Parser",                package: "biokinetics-dosimetry"),
                .product(name: "FP",                    package: "FP"),
                .product(name: "Core",                  package: "NetworkTools"),
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                "UIComponents",
            ]
        ),

        .target(
            name: "EditorFeature",
            dependencies: [
                "AppDomain",
                .product(name: "Domain",                  package: "biokinetics-dosimetry"),
                .product(name: "SwiftRex",                package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture",   package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency",    package: "SwiftRex"),
                "UIComponents",
            ]
        ),

        .target(
            name: "CalculatorFeature",
            dependencies: [
                "AppDomain",
                .product(name: "Domain",                  package: "biokinetics-dosimetry"),
                .product(name: "Solver",                  package: "biokinetics-dosimetry"),
                .product(name: "FP",                      package: "FP"),
                .product(name: "SwiftRex",                package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture",   package: "SwiftRex"),
                .product(name: "SwiftRex.ReactiveConcurrency",    package: "SwiftRex"),
                "UIComponents",
            ]
        ),

        // MARK: - App core (wires features + navigation + home)

        .target(
            name: "AppCore",
            dependencies: [
                "AppDomain",
                "HomeFeature",
                "EditorFeature",
                "CalculatorFeature",
                .product(name: "Domain",                package: "biokinetics-dosimetry"),
                .product(name: "Solver",                package: "biokinetics-dosimetry"),
                .product(name: "SwiftRex",              package: "SwiftRex"),
                .product(name: "SwiftRex.SwiftUI",      package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Operators",    package: "SwiftRex"),
                .product(name: "FP",                    package: "FP"),
                .product(name: "CoreFP",                package: "FP"),
                .product(name: "CoreFPOperators",       package: "FP"),
                .product(name: "FPMacros",              package: "FP"),
                .product(name: "Core",                  package: "NetworkTools"),
                .product(name: "XMLCoder",              package: "XMLCoder"),
                "UIComponents",
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "EditorFeatureTests",
            dependencies: [
                "EditorFeature",
                .product(name: "SwiftRex",             package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Testing",     package: "SwiftRex"),
                .product(name: "SnapshotTesting",      package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "CalculatorFeatureTests",
            dependencies: [
                "CalculatorFeature",
                .product(name: "Domain",               package: "biokinetics-dosimetry"),
                .product(name: "Solver",               package: "biokinetics-dosimetry"),
                .product(name: "SwiftRex",             package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Testing",     package: "SwiftRex"),
                .product(name: "SnapshotTesting",      package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: [
                "AppCore",
                "AppDomain",
                "HomeFeature",
                "EditorFeature",
                "CalculatorFeature",
                .product(name: "FP",                   package: "FP"),
                .product(name: "SwiftRex.SwiftUI",     package: "SwiftRex"),
                .product(name: "Core",                 package: "NetworkTools"),
                .product(name: "SwiftRex",             package: "SwiftRex"),
                .product(name: "SwiftRex.Architecture", package: "SwiftRex"),
                .product(name: "SwiftRex.Testing",     package: "SwiftRex"),
                .product(name: "SnapshotTesting",      package: "swift-snapshot-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
