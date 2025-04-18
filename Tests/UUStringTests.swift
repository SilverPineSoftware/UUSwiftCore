//
//  UUJsonTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 04/18/25.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

final class UUStringTests: XCTestCase
{
    func testFixedWidthIntegerToBinaryString()
    {
        // UInt8 examples
        XCTAssertEqual(UInt8(1).uuToBinaryString(), "00000001")
        XCTAssertEqual(UInt8(0xFF).uuToBinaryString(), "11111111")
        XCTAssertEqual(UInt8(0xA5).uuToBinaryString(), "10100101")

        // Int8 (two's complement)
        XCTAssertEqual(Int8(-1).uuToBinaryString(), "11111111")
        XCTAssertEqual(Int8(-128).uuToBinaryString(), "10000000")

        // UInt16 example
        XCTAssertEqual(UInt16(0x1234).uuToBinaryString(), "0001001000110100")
        // Int16 (two's complement)
        XCTAssertEqual(Int16(-1).uuToBinaryString(), "1111111111111111")
    }

    func testDataToBinaryString()
    {
        // Multi-byte data
        let data1 = Data([0xFF, 0x00, 0xA5])
        XCTAssertEqual(data1.uuToBinaryString(), "11111111 00000000 10100101")

        let data2 = Data([0x00, 0xF0])
        XCTAssertEqual(data2.uuToBinaryString(), "00000000 11110000")

        // Empty data should produce an empty string
        let emptyData = Data()
        XCTAssertEqual(emptyData.uuToBinaryString(), "")
    }
}
