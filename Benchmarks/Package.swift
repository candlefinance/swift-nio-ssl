// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "benchmarks",
    platforms: [
        .macOS("14")
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.54.0"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.22.0"),
    ],
    targets: [
        .executableTarget(
            name: "NIOSSLBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "CandleNIOSSL", package: "swift-nio-ssl"),
                .product(name: "CandleNIOCore", package: "swift-nio"),
                .product(name: "CandleNIOEmbedded", package: "swift-nio"),
            ],
            path: "Benchmarks/NIOSSLBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
