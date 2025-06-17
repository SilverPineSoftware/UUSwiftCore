
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
    
    func test_uuByteSize_static() throws
    {
        XCTAssertEqual(8, UInt64.uuByteSize)
        XCTAssertEqual(8, Int64.uuByteSize)
        XCTAssertEqual(4, UInt32.uuByteSize)
        XCTAssertEqual(4, Int32.uuByteSize)
        XCTAssertEqual(2, UInt16.uuByteSize)
        XCTAssertEqual(2, Int16.uuByteSize)
        XCTAssertEqual(1, UInt8.uuByteSize)
        XCTAssertEqual(1, Int8.uuByteSize)
    }
    
    func test_uuByteSize_instance() throws
    {
        XCTAssertEqual(8, UInt64(0).uuByteSize)
        XCTAssertEqual(8, Int64(0).uuByteSize)
        XCTAssertEqual(4, UInt32(0).uuByteSize)
        XCTAssertEqual(4, Int32(0).uuByteSize)
        XCTAssertEqual(2, UInt16(0).uuByteSize)
        XCTAssertEqual(2, Int16(0).uuByteSize)
        XCTAssertEqual(1, UInt8(0).uuByteSize)
        XCTAssertEqual(1, Int8(0).uuByteSize)
    }
}
