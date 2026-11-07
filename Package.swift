// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kanta",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Kanta", targets: ["Kanta"])],
    targets: [
        .executableTarget(name: "Kanta"),
        .testTarget(name: "KantaTests", dependencies: ["Kanta"])
    ]
)
