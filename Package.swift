// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MultiCompartmentModel",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MultiCompartmentModel", targets: ["MultiCompartmentModel"])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.7.0"),
        .package(url: "https://github.com/luizmb/NetworkTools.git", from: "0.2.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0"),
        // Local path while Phase B fixes (rk4 double-add + vector-state) are unreleased.
        // Switch to `.package(url: "https://github.com/luizmb/RungeKutta.git", from: "...")` once tagged.
        .package(path: "../RungeKutta")
    ],
    targets: [
        .target(
            name: "MultiCompartmentModel",
            dependencies: [
                .product(name: "FP", package: "FP"),
                .product(name: "FPMacros", package: "FP"),
                .product(name: "Core", package: "NetworkTools"),
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "RungeKutta", package: "RungeKutta")
            ]
        ),
        .testTarget(
            name: "MultiCompartmentModelTests",
            dependencies: ["MultiCompartmentModel"],
            resources: [.process("Fixtures")]
        )
    ]
)
