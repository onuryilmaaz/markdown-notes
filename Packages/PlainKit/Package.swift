// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PlainKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PlainDomain", targets: ["PlainDomain"]),
        .library(name: "PlainDesignSystem", targets: ["PlainDesignSystem"]),
        .library(name: "PlainPersistence", targets: ["PlainPersistence"]),
        .library(name: "PlainActivity", targets: ["PlainActivity"])
    ],
    targets: [
        .target(name: "PlainDomain", resources: [.process("Resources")]),
        .target(name: "PlainDesignSystem", dependencies: ["PlainDomain"]),
        .target(name: "PlainPersistence", dependencies: ["PlainDomain"]),
        .target(name: "PlainActivity", dependencies: ["PlainDomain"])
    ],
    swiftLanguageModes: [.v5]
)
