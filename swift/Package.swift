// swift-tools-version: 5.9
import PackageDescription

// Resources (audio/) live in swift/Resources/ and are copied into the
// app bundle by build.sh — not managed by SPM. At runtime the app reads
// them via Bundle.main, which works once build.sh puts them in
// Pommy.app/Contents/Resources/.
let package = Package(
    name: "Pommy",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pommy",
            path: "Sources/Pommy"
        )
    ]
)
