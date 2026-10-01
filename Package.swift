// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PhotoCore", platforms: [.macOS("27.0"), .iOS("27.0")],
  products: [.library(name: "PhotoCore", targets: ["PhotoCore"])],
  targets: [
    .target(name: "PhotoCore", path: "Sources/Core"),
    .target(
      name: "PhotoPersistence", dependencies: ["PhotoCore"], path: "Sources/App",
      exclude: ["PhotoApp.swift"], sources: ["PhotoRecord.swift"]),
    .testTarget(name: "PhotoCoreTests", dependencies: ["PhotoCore"], path: "Tests/Core"),
    .testTarget(
      name: "PhotoPersistenceTests", dependencies: ["PhotoCore", "PhotoPersistence"],
      path: "Tests/Persistence"),
  ])
