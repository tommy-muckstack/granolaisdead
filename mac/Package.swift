// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GranolaIsDead",
    // 14.2 floor: the CoreAudio process tap (system audio without a bot) needs it.
    platforms: [.macOS("14.2")],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.0"),
        // Pinned: the same build My Man ships (Parakeet ASR + pyannote diarizer).
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.1"),
    ],
    targets: [
        .target(name: "AudioEngineSafety", path: "support/AudioEngineSafety"),
        .executableTarget(
            name: "GranolaIsDead",
            dependencies: [
                "AudioEngineSafety",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "src",
            resources: [.copy("Resources/Fonts")]
        ),
        .testTarget(name: "GranolaIsDeadTests", dependencies: ["GranolaIsDead"], path: "Tests"),
    ]
)
