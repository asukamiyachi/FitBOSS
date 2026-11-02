// swift-tools-version: 5.9
import Foundation
import PackageDescription

// FITBOSS_FIREBASE_ENABLED=1 swift build enables the official cloud client.
// Camera-only CI stays offline, dependency-free and testable without credentials.
let enabled = ProcessInfo.processInfo.environment["FITBOSS_FIREBASE_ENABLED"] == "1"
let extraPackages: [Package.Dependency] = enabled ? [
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "9.0.0")
] : []
var appDependencies: [Target.Dependency] = ["FitBOSSCore"]
if enabled {
    appDependencies += [
        .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
        .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
        .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
        .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
        .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
        .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
    ]
}
let package = Package(
    name: "FitBOSS",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FitBOSSApp", targets: ["FitBOSSApp"]),
        .library(name: "FitBOSSCore", targets: ["FitBOSSCore"])
    ],
    dependencies: extraPackages,
    targets: [
        .target(name: "FitBOSSCore", path: "Sources/FitBOSSCore"),
        .executableTarget(name: "FitBOSSApp", dependencies: appDependencies, path: "Sources/FitBOSSApp", swiftSettings: enabled ? [.define("FITBOSS_FIREBASE_ENABLED")] : []),
        .testTarget(name: "FitBOSSCoreTests", dependencies: ["FitBOSSCore"], path: "Tests/FitBOSSCoreTests"),
        .testTarget(name: "FitBOSSAppTests", dependencies: ["FitBOSSApp"], path: "Tests/FitBOSSAppTests")
    ]
)
