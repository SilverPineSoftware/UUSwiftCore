//
//  UUCollectionTests.swift
//  UUSwiftCore
//

import XCTest
@testable import UUSwiftCore

final class UUCollectionTests: XCTestCase
{
    func test_safeSubscript_returnsElementForValidArrayIndex()
    {
        let values = ["a", "b", "c"]

        XCTAssertEqual(values[safe: 1], "b")
    }

    func test_safeSubscript_returnsNilForInvalidArrayIndex()
    {
        let values = ["a", "b", "c"]

        XCTAssertNil(values[safe: values.endIndex])
    }

    func test_safeSubscript_worksWithStringIndices()
    {
        let value = "hello"
        let index = value.index(after: value.startIndex)

        XCTAssertEqual(value[safe: index], "e")
    }
}
