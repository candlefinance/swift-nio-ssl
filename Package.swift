// swift-tools-version:5.10
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import PackageDescription

// Used only for environment variables, does not make its way
// into the product code.
import class Foundation.ProcessInfo

// This package contains a vendored copy of BoringSSL. For ease of tracking
// down problems with the copy of BoringSSL in use, we include a copy of the
// commit hash of the revision of BoringSSL included in the given release.
// This is also reproduced in a file called hash.txt in the
// Sources/CNIOBoringSSL directory. The source repository is at
// https://boringssl.googlesource.com/boringssl.
//
// BoringSSL Commit: 817ab07ebb53da35afea409ab9328f578492832d

/// This function generates the dependencies we want to express.
///
/// Importantly, it tolerates the possibility that we are being used as part
/// of the Swift toolchain, and so need to use local checkouts of our
/// dependencies.
func generateDependencies() -> [Package.Dependency] {
    if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
        return [
            .package(url: "https://github.com/candlefinance/swift-nio.git", name: "candle-swift-nio", branch: "fix-candle-2.82.1")
        ]
    } else {
        return [
            .package(path: "../swift-nio", name: "candle-swift-nio")
        ]
    }
}

// This doesn't work when cross-compiling: the privacy manifest will be included in the Bundle and
// Foundation will be linked. This is, however, strictly better than unconditionally adding the
// resource.
#if canImport(Darwin)
let includePrivacyManifest = true
#else
let includePrivacyManifest = false
#endif

let strictConcurrencyDevelopment = false

let strictConcurrencySettings: [SwiftSetting] = {
    var initialSettings: [SwiftSetting] = []
    initialSettings.append(contentsOf: [
        .enableUpcomingFeature("StrictConcurrency"),
        .enableUpcomingFeature("InferSendableFromCaptures"),
    ])

    if strictConcurrencyDevelopment {
        // -warnings-as-errors here is a workaround so that IDE-based development can
        // get tripped up on -require-explicit-sendable.
        initialSettings.append(.unsafeFlags(["-Xfrontend", "-require-explicit-sendable", "-warnings-as-errors"]))
    }

    return initialSettings
}()

// swift-format-ignore: NoBlockComments
let package = Package(
    name: "candle-swift-nio-ssl",
    products: [
        .library(name: "CandleNIOSSL", targets: ["CandleNIOSSL"]),
        .executable(name: "NIOTLSServer", targets: ["NIOTLSServer"]),
        .executable(name: "NIOSSLHTTP1Client", targets: ["NIOSSLHTTP1Client"]),
        /* This target is used only for symbol mangling. It's added and removed automatically because it emits build warnings. MANGLE_START
                .library(name: "CandleCNIOBoringSSL", type: .static, targets: ["CandleCNIOBoringSSL"]),
        MANGLE_END */
    ],
    dependencies: generateDependencies(),
    targets: [
        .target(
            name: "CandleCNIOBoringSSL",
            cSettings: [
                .define("_GNU_SOURCE"),
                .define("_POSIX_C_SOURCE", to: "200112L"),
                .define("_DARWIN_C_SOURCE"),
            ]
        ),
        .target(
            name: "CandleCNIOBoringSSLShims",
            dependencies: [
                "CandleCNIOBoringSSL"
            ],
            cSettings: [
                .define("_GNU_SOURCE")
            ]
        ),
        .target(
            name: "CandleNIOSSL",
            dependencies: [
                "CandleCNIOBoringSSL",
                "CandleCNIOBoringSSLShims",
                .product(name: "CandleNIO", package: "candle-swift-nio"),
                .product(name: "CandleNIOCore", package: "candle-swift-nio"),
                .product(name: "CandleNIOConcurrencyHelpers", package: "candle-swift-nio"),
                .product(name: "CandleNIOTLS", package: "candle-swift-nio"),
            ],
            exclude: includePrivacyManifest ? [] : ["PrivacyInfo.xcprivacy"],
            resources: includePrivacyManifest ? [.copy("PrivacyInfo.xcprivacy")] : [],
            swiftSettings: strictConcurrencySettings
        ),
        .executableTarget(
            name: "NIOTLSServer",
            dependencies: [
                "CandleNIOSSL",
                .product(name: "CandleNIOCore", package: "candle-swift-nio"),
                .product(name: "CandleNIOPosix", package: "candle-swift-nio"),
                .product(name: "CandleNIOConcurrencyHelpers", package: "candle-swift-nio"),
            ],
            exclude: [
                "README.md"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .executableTarget(
            name: "NIOSSLHTTP1Client",
            dependencies: [
                "CandleNIOSSL",
                .product(name: "CandleNIOCore", package: "candle-swift-nio"),
                .product(name: "CandleNIOPosix", package: "candle-swift-nio"),
                .product(name: "CandleNIOHTTP1", package: "candle-swift-nio"),
                .product(name: "CandleNIOFoundationCompat", package: "candle-swift-nio"),
            ],
            exclude: [
                "README.md"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .executableTarget(
            name: "NIOSSLPerformanceTester",
            dependencies: [
                "CandleNIOSSL",
                .product(name: "CandleNIOCore", package: "candle-swift-nio"),
                .product(name: "CandleNIOEmbedded", package: "candle-swift-nio"),
                .product(name: "CandleNIOTLS", package: "candle-swift-nio"),
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "NIOSSLTests",
            dependencies: [
                "CandleNIOSSL",
                .product(name: "CandleNIOCore", package: "candle-swift-nio"),
                .product(name: "CandleNIOEmbedded", package: "candle-swift-nio"),
                .product(name: "CandleNIOPosix", package: "candle-swift-nio"),
                .product(name: "CandleNIOTLS", package: "candle-swift-nio"),
            ],
            swiftSettings: strictConcurrencySettings
        ),
    ],
    cxxLanguageStandard: .cxx17
)

// ---    STANDARD CROSS-REPO SETTINGS DO NOT EDIT   --- //
for target in package.targets {
    switch target.type {
    case .regular, .test, .executable:
        var settings = target.swiftSettings ?? []
        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
        settings.append(.enableUpcomingFeature("MemberImportVisibility"))
        target.swiftSettings = settings
    case .macro, .plugin, .system, .binary:
        ()  // not applicable
    @unknown default:
        ()  // we don't know what to do here, do nothing
    }
}
// --- END: STANDARD CROSS-REPO SETTINGS DO NOT EDIT --- //
