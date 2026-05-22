// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MultiCompartmentModel",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MultiCompartmentModel", targets: ["MultiCompartmentModel"])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.8.1"),
        .package(url: "https://github.com/luizmb/NetworkTools.git", from: "0.5.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0"),
        .package(url: "https://github.com/luizmb/SwiftCalx.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "MultiCompartmentModel",
            dependencies: [
                .product(name: "FP", package: "FP"),
                .product(name: "FPMacros", package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "Math", package: "SwiftCalx"),
                .product(name: "Calculus", package: "SwiftCalx"),
                .product(name: "RungeKutta", package: "SwiftCalx")
            ]
        ),
        .testTarget(
            name: "MultiCompartmentModelTests",
            dependencies: ["MultiCompartmentModel"],
            resources: [.process("Fixtures")]
        )
    ]
)
