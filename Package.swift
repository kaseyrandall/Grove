// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GroveBattle",
    products: [.library(name: "GroveBattle", targets: ["GroveBattle"])],
    targets: [
        .target(name: "GroveBattle"),
        .testTarget(name: "GroveBattleTests", dependencies: ["GroveBattle"]),
    ]
)
