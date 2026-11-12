// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "moonetix_offerwall",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "moonetix-offerwall", targets: ["moonetix_offerwall"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "MoonetixOfferwall",
            path: "Frameworks/MoonetixOfferwall.xcframework"
        ),
        .target(
            name: "moonetix_offerwall",
            dependencies: [
                "MoonetixOfferwall",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
