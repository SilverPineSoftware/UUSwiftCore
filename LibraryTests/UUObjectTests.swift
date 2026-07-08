//
//  UUObjectTests.swift
//  UUSwiftCore
//

import Foundation
import XCTest
@testable import UUSwiftCore

private final class AssociatedObjectHost: NSObject
{
}

final class UUObjectTests: XCTestCase
{
    func test_uuClassName_returnsTypeName()
    {
        XCTAssertEqual(AssociatedObjectHost.uuClassName, "AssociatedObjectHost")
    }
}
