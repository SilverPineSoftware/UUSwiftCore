//
//  UUComparableTests.swift
//  UUSwiftCore
//

import XCTest
@testable import UUSwiftCore

final class UUComparableTests: XCTestCase
{
    func test_uuClamp_returnsValueInsideRange()
    {
        XCTAssertEqual(5.uuClamp(low: 1, high: 10), 5)
    }

    func test_uuClamp_returnsLowerBoundWhenValueIsBelowRange()
    {
        XCTAssertEqual((-1).uuClamp(low: 1, high: 10), 1)
    }

    func test_uuClamp_returnsUpperBoundWhenValueIsAboveRange()
    {
        XCTAssertEqual(11.uuClamp(low: 1, high: 10), 10)
    }

    func test_uuClamp_worksWithComparableStrings()
    {
        XCTAssertEqual("m".uuClamp(low: "a", high: "f"), "f")
    }
}
