// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Microscope",
    platforms: [.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Microscope",
            targets: ["Microscope"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/Gardener", from: "0.0.48"),
        .package(url: "https://github.com/OperatorFoundation/swift-ast", from: "0.19.12"),
        .package(url: "https://github.com/OperatorFoundation/Sculpture", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Microscope",
            dependencies: ["Gardener", "swift-ast", "Sculpture"]),
        .testTarget(
            name: "MicroscopeTests",
            dependencies: ["Microscope"]),
    ],
    swiftLanguageVersions: [.v5]
)
