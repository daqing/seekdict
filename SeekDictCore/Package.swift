// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SeekDictCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SeekDictCore", targets: ["SeekDictCore"]),
    ],
    targets: [
        .target(
            name: "SeekDictCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(name: "SeekDictCoreTests", dependencies: ["SeekDictCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
