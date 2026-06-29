// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Handometer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Handometer",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Handometer",
            linkerSettings: [
                // Permet au binaire de trouver Sparkle.framework copié dans
                // Contents/Frameworks du bundle .app.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
