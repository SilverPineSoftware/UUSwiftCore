//
//  UUURLTests.swift
//  UUSwiftCore
//

import XCTest
@testable import UUSwiftCore

final class UUURLTests: XCTestCase
{
    func test_uuQueryParameters_returnsDecodedQueryItems()
    {
        let url = URL(string: "https://example.com/path?name=Ryan%20Devore&city=Seattle")!

        XCTAssertEqual(url.uuQueryParameters["name"], "Ryan Devore")
        XCTAssertEqual(url.uuQueryParameters["city"], "Seattle")
    }

    func test_uuQueryParameters_returnsEmptyDictionaryWhenURLHasNoQuery()
    {
        let url = URL(string: "https://example.com/path")!

        XCTAssertEqual(url.uuQueryParameters, [:])
    }

    func test_uuQueryParameters_lastDuplicateValueWins()
    {
        let url = URL(string: "https://example.com/path?item=first&item=second")!

        XCTAssertEqual(url.uuQueryParameters["item"], "second")
    }

    func test_uuQueryParameters_dropsQueryItemsWithoutValues()
    {
        let url = URL(string: "https://example.com/path?flag")!

        XCTAssertFalse(url.uuQueryParameters.keys.contains("flag"))
    }
}
