// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JournalCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "JournalCore", targets: ["JournalCore"])],
    targets: [
        .target(name: "JournalCore"),
        .testTarget(name: "JournalCoreTests", dependencies: ["JournalCore"], resources: [.copy("Fixtures")])
    ]
)
