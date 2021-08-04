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
	targets: [
		.target(
			name: "UUSwiftCore",
			dependencies: [],
			path: "UUSwiftCore",
			exclude: ["Info.plist"])
	],
	swiftLanguageVersions: [
		.v4_2,
		.v5
	]
)