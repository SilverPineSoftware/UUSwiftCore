// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "UUSwiftCore",
	platforms: [
		.iOS(.v15),
		.macOS(.v11)
	],

	products: [
		// Products define the executables and libraries a package produces, and make them visible to other packages.
		.library(
			name: "UUSwiftCore",
			targets: ["UUSwiftCore"]),
	],
    
    dependencies: [
        .package(
            url: "https://github.com/SilverPineSoftware/UUSwiftTestCore.git",
            from: "0.0.5"
        )
    ],
    
	targets: [
		.target(
			name: "UUSwiftCore",
			dependencies: [],
			path: "Library",
			exclude: ["Info.plist"],
            resources: [
                .copy("PrivacyInfo.xcprivacy")]),
        .testTarget(
            name: "UUSwiftCoreTests",
            dependencies: ["UUSwiftTestCore", "UUSwiftCore"],
            path: "LibraryTests",
            exclude: ["UnitTests.xctestplan"],
            resources: [.process("Resources")]),
	],
    swiftLanguageModes: [
		.v4_2,
		.v5,
        .v6
	]
)
