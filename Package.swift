// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "UUSwiftCore",
	platforms: [
		.iOS(.v10),
		.macOS(.v10_15)
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
            from: "0.0.3"
        )
    ],
    
	targets: [
		.target(
			name: "UUSwiftCore",
			dependencies: [],
			path: "UUSwiftCore",
			exclude: ["Info.plist"]),
        .testTarget(
            name: "UUSwiftCoreTests",
            dependencies: ["UUSwiftTestCore", "UUSwiftCore"],
            path: "Tests"),
	],
	swiftLanguageVersions: [
		.v4_2,
		.v5
	]
)
