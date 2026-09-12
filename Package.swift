// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PickBrowser",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PickBrowser", targets: ["PickBrowser"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .target(name: "PickBrowserCore"),
        .executableTarget(name: "PickBrowser", dependencies: ["PickBrowserCore", .product(name: "Sparkle", package: "Sparkle")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PickBrowserCoreTests", dependencies: ["PickBrowserCore"],
                    resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
