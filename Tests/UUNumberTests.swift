
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
    // MARK: uuClamp tests
    
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
    
    // MARK: uuByteSize tests
    
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
    
    // MARK: uuClearingBit tests
    
    struct BitTwiddlingTestInput<NumberType: FixedWidthInteger>
    {
        let input: NumberType
        let expected: NumberType
        let index: Int
        
        init(_ input: NumberType, _ expected: NumberType, _ index: Int)
        {
            self.input = input
            self.expected = expected
            self.index = index
        }
    }
    
    func test_uuBitTwiddling_UInt8()
    {
        let inputs : [BitTwiddlingTestInput<UInt8>] =
        [
            BitTwiddlingTestInput(0b0000_0001, 0b0000_0000, 0),
            BitTwiddlingTestInput(0b0000_0100, 0b0000_0000, 2),
            BitTwiddlingTestInput(0b0010_0000, 0b0000_0000, 5),
            BitTwiddlingTestInput(0b1000_0000, 0b0000_0000, 7),
            
            BitTwiddlingTestInput(0b1111_0001, 0b1111_0000, 0),
            BitTwiddlingTestInput(0b1110_0100, 0b1110_0000, 2),
            BitTwiddlingTestInput(0b0010_0111, 0b0000_0111, 5),
            BitTwiddlingTestInput(0b1000_1111, 0b0000_1111, 7),
            
            // Out of bounds tests
            BitTwiddlingTestInput(0b1000_1111, 0b1000_1111, -1),
            BitTwiddlingTestInput(0b1000_1111, 0b1000_1111, 8),
        ]
        
        for td in inputs
        {
            let clearOutput = td.input.uuClearBit(at: td.index)
            XCTAssertEqual(td.expected, clearOutput)
            
            let setOutput = clearOutput.uuSetBit(to: true, at: td.index)
            XCTAssertEqual(td.input, setOutput)
            
            // Xor original once should get to our 'cleared' expectation
            let xorOutput = td.input.uuXorBit(at: td.index)
            XCTAssertEqual(td.expected, xorOutput)
            
            // Xor again and we should then get back our original
            let xorOutput2 = xorOutput.uuXorBit(at: td.index)
            XCTAssertEqual(td.input, xorOutput2)
            
            // Set to false clears it
            let setOutput2 = xorOutput2.uuSetBit(to: false, at: td.index)
            XCTAssertEqual(td.expected, setOutput2)
        }
    }
    
    func test_uuBitTwiddling_Int8()
    {
        let inputs : [BitTwiddlingTestInput<Int8>] =
        [
            BitTwiddlingTestInput(0b0000_0001, 0b0000_0000, 0),
            BitTwiddlingTestInput(0b0000_0100, 0b0000_0000, 2),
            BitTwiddlingTestInput(0b0010_0000, 0b0000_0000, 5),
            BitTwiddlingTestInput(0b0100_0000, 0b0000_0000, 6),
            
            BitTwiddlingTestInput(0b0111_0001, 0b0111_0000, 0),
            BitTwiddlingTestInput(0b0110_0100, 0b0110_0000, 2),
            BitTwiddlingTestInput(0b0010_0111, 0b0000_0111, 5),
            BitTwiddlingTestInput(0b0100_1111, 0b0000_1111, 6),
            
            // Out of bounds tests
            BitTwiddlingTestInput(0b0000_1111, 0b0000_1111, -1),
            BitTwiddlingTestInput(0b0000_1111, 0b0000_1111, 8),
        ]
        
        for td in inputs
        {
            let clearOutput = td.input.uuClearBit(at: td.index)
            XCTAssertEqual(td.expected, clearOutput)
            
            let setOutput = clearOutput.uuSetBit(to: true, at: td.index)
            XCTAssertEqual(td.input, setOutput)
            
            // Xor original once should get to our 'cleared' expectation
            let xorOutput = td.input.uuXorBit(at: td.index)
            XCTAssertEqual(td.expected, xorOutput)
            
            // Xor again and we should then get back our original
            let xorOutput2 = xorOutput.uuXorBit(at: td.index)
            XCTAssertEqual(td.input, xorOutput2)
            
            // Set to false clears it
            let setOutput2 = xorOutput2.uuSetBit(to: false, at: td.index)
            XCTAssertEqual(td.expected, setOutput2)
        }
    }
    
    func test_uuBitTwiddling_UInt32()
    {
        let inputs : [BitTwiddlingTestInput<UInt32>] =
        [
            BitTwiddlingTestInput(0b0000_0001, 0b0000_0000, 0),
            BitTwiddlingTestInput(0b0000_0100, 0b0000_0000, 2),
            BitTwiddlingTestInput(0b0010_0000, 0b0000_0000, 5),
            BitTwiddlingTestInput(0b1000_0000, 0b0000_0000, 7),
            
            BitTwiddlingTestInput(0b1111_0001, 0b1111_0000, 0),
            BitTwiddlingTestInput(0b1110_0100, 0b1110_0000, 2),
            BitTwiddlingTestInput(0b0010_0111, 0b0000_0111, 5),
            BitTwiddlingTestInput(0b1000_1111, 0b0000_1111, 7),
            
            // Out of bounds tests
            BitTwiddlingTestInput(0b1000_1111, 0b1000_1111, -1),
            BitTwiddlingTestInput(0b1000_1111, 0b1000_1111, 33),
        ]
        
        for td in inputs
        {
            let clearOutput = td.input.uuClearBit(at: td.index)
            XCTAssertEqual(td.expected, clearOutput)
            
            let setOutput = clearOutput.uuSetBit(to: true, at: td.index)
            XCTAssertEqual(td.input, setOutput)
            
            // Xor original once should get to our 'cleared' expectation
            let xorOutput = td.input.uuXorBit(at: td.index)
            XCTAssertEqual(td.expected, xorOutput)
            
            // Xor again and we should then get back our original
            let xorOutput2 = xorOutput.uuXorBit(at: td.index)
            XCTAssertEqual(td.input, xorOutput2)
            
            // Set to false clears it
            let setOutput2 = xorOutput2.uuSetBit(to: false, at: td.index)
            XCTAssertEqual(td.expected, setOutput2)
        }
    }
    
    func test_uuBitTwiddling_Int16()
    {
        let inputs : [BitTwiddlingTestInput<Int16>] =
        [
            BitTwiddlingTestInput(0b0000_0001, 0b0000_0000, 0),
            BitTwiddlingTestInput(0b0000_0100, 0b0000_0000, 2),
            BitTwiddlingTestInput(0b0010_0000, 0b0000_0000, 5),
            BitTwiddlingTestInput(0b0100_0000, 0b0000_0000, 6),
            
            BitTwiddlingTestInput(0b0111_0001, 0b0111_0000, 0),
            BitTwiddlingTestInput(0b0110_0100, 0b0110_0000, 2),
            BitTwiddlingTestInput(0b0010_0111, 0b0000_0111, 5),
            BitTwiddlingTestInput(0b0100_1111, 0b0000_1111, 6),
            
            // Out of bounds tests
            BitTwiddlingTestInput(0b0000_1111, 0b0000_1111, -1),
            BitTwiddlingTestInput(0b0000_1111, 0b0000_1111, 16),
        ]
        
        for td in inputs
        {
            let clearOutput = td.input.uuClearBit(at: td.index)
            XCTAssertEqual(td.expected, clearOutput)
            
            let setOutput = clearOutput.uuSetBit(to: true, at: td.index)
            XCTAssertEqual(td.input, setOutput)
            
            // Xor original once should get to our 'cleared' expectation
            let xorOutput = td.input.uuXorBit(at: td.index)
            XCTAssertEqual(td.expected, xorOutput)
            
            // Xor again and we should then get back our original
            let xorOutput2 = xorOutput.uuXorBit(at: td.index)
            XCTAssertEqual(td.input, xorOutput2)
            
            // Set to false clears it
            let setOutput2 = xorOutput2.uuSetBit(to: false, at: td.index)
            XCTAssertEqual(td.expected, setOutput2)
        }
    }
    
    func test_uuToBcd8()
    {
        let inputs: [(Int, Int?)] =
        [
            (12, 0x12),
            (99, 0x99),
            (00, 0x00),
            (100, nil),
            (-1, nil),
            (78, 0x78)
        ]
        
        for td in inputs
        {
            let actual = td.0.uuToBcd8()
            XCTAssertEqual(td.1, actual)
        }
    }
    
    func test_uuFromBcd8()
    {
        let inputs: [(Int, Int)] =
        [
            (12, 0x12),
            (99, 0x99),
            (00, 0x00),
            (78, 0x78)
        ]
        
        for td in inputs
        {
            let actual = td.1.uuFromBcd8()
            XCTAssertEqual(td.0, actual)
        }
    }
    
    func testYearsDivisibleBy400_AreLeapYears()
    {
        XCTAssertTrue(1600.uuIsLeapYear)
        XCTAssertTrue(2000.uuIsLeapYear)
        XCTAssertTrue(2400.uuIsLeapYear)
    }

    func testYearsDivisibleBy100_ButNot400_AreNotLeapYears()
    {
        XCTAssertFalse(1700.uuIsLeapYear)
        XCTAssertFalse(1800.uuIsLeapYear)
        XCTAssertFalse(1900.uuIsLeapYear)
    }

    func testYearsDivisibleBy4_ButNot100_AreLeapYears()
    {
        XCTAssertTrue(1996.uuIsLeapYear)
        XCTAssertTrue(2004.uuIsLeapYear)
        XCTAssertTrue(2024.uuIsLeapYear)
    }

    func testYearsNotDivisibleBy4_AreNotLeapYears()
    {
        XCTAssertFalse(1999.uuIsLeapYear)
        XCTAssertFalse(2001.uuIsLeapYear)
        XCTAssertFalse(2023.uuIsLeapYear)
    }

    func testNegativeYearsAndZero()
    {
        // Historically negative years aren't used this way,
        // but mathematically the same leap-year rules apply.
        XCTAssertTrue(0.uuIsLeapYear)    // divisible by 400
        XCTAssertTrue((-4).uuIsLeapYear) // divisible by 4
        XCTAssertFalse((-1).uuIsLeapYear)
    }
}
