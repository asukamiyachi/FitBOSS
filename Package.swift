// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitBOSS",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FitBOSSApp", targets: ["FitBOSSApp"]),
        .library(name: "FitBOSSCore", targets: ["FitBOSSCore"])
    ],
    targets: [
        .target(name: "FitBOSSCore", path: "Sources/FitBOSSCore"),
        .executableTarget(name: "FitBOSSApp", dependencies: ["FitBOSSCore"], path: "Sources/FitBOSSApp"),
        .testTarget(name: "FitBOSSCoreTests", dependencies: ["FitBOSSCore"], path: "Tests/FitBOSSCoreTests")
    ]
)
