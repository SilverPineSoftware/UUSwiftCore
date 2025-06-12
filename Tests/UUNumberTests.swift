
//
//  UUNumberTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 06/11/25.
//

import XCTest
import UUSwiftTestCore

@testable import UUSwiftCore

final class UUNumberTests: XCTestCase
{
    func test_uuClamp_inRange() throws
    {
        let input: Int = 10
        let clamped = input.uuClamp(min: 5, max: 15)
        XCTAssertEqual(10, clamped)
    }
    
    func test_uuClamp_below() throws
    {
        let input: Int = 10
        let clamped = input.uuClamp(min: 15, max: 20)
        XCTAssertEqual(15, clamped)
    }
    
    func test_uuClamp_above() throws
    {
        let input: Int = 10
        let clamped = input.uuClamp(min: 2, max: 8)
        XCTAssertEqual(8, clamped)
    }
    
    func test_uuClamp_equalMin() throws
    {
        let input: Int = 15
        let clamped = input.uuClamp(min: 15, max: 20)
        XCTAssertEqual(15, clamped)
    }
    
    func test_uuClamp_equalMax() throws
    {
        let input: Int = 8
        let clamped = input.uuClamp(min: 2, max: 8)
        XCTAssertEqual(8, clamped)
    }
}
