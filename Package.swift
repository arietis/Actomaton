// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Actomaton",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "Actomaton",
            targets: ["Actomaton", "ActomatonDebugging"]),
        .library(
            name: "ActomatonStore",
            targets: ["ActomatonStore", "ActomatonDebugging"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.7.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "Actomaton",
            dependencies: [.product(name: "CasePaths", package: "swift-case-paths")]),
        .target(
            name: "ActomatonStore",
            dependencies: [
                "Actomaton",
                .product(name: "CasePaths", package: "swift-case-paths")
            ]),
        .target(
            name: "ActomatonDebugging",
            dependencies: [
                "Actomaton",
                .product(name: "CustomDump", package: "swift-custom-dump")
            ]),
        .testTarget(
            name: "ActomatonTests",
            dependencies: ["Actomaton"]),
    ]
)
