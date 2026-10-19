// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ATVRemote",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ATVRemote",
            path: "Sources/ATVRemote",
            resources: [
                .copy("Resources/wsserver.py"),
                .copy("Resources/requirements.txt"),
                .copy("Resources/start_server.sh"),
                .copy("Resources/IconTemplate.png"),
                .copy("Resources/icon.png"),
                .copy("Resources/icon@2x.png")
            ]
        )
    ]
)
