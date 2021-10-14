//
//  UUDataTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 10/14/21.
//

import XCTest
@testable import UUSwiftCore

class UUDataTests: XCTestCase
{
    // MARK: uuToHexString
    
    private func do_uuToHexString_test(_ bytes: [UInt8], _ expected: String)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuToHexString()
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuToHexString_empty()
    {
        do_uuToHexString_test([], "")
    }
    
    func test_uuToHexString_single()
    {
        do_uuToHexString_test([1], "01")
    }
    
    func test_uuToHexString_many()
    {
        do_uuToHexString_test([1, 2, 3], "010203")
    }
    
    func test_uuToHexString_minMax()
    {
        do_uuToHexString_test([00, 0xFF, 00, 0xFF], "00FF00FF")
    }
    
    func test_uuToHexString_random()
    {
        do_uuToHexString_test([8, 6, 7, 5, 3, 0, 9], "08060705030009")
        do_uuToHexString_test([0xDE, 0xAD, 0xBE, 0xEF], "DEADBEEF")
    }
    
    // MARK: uuBytes
    
    private func do_uuBytes_test(_ bytes: [UInt8])
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuBytes
        XCTAssertEqual(bytes, actual)
    }
    
    func test_uuBytes_empty()
    {
        do_uuBytes_test([])
    }
    
    func test_uuBytes_random()
    {
        do_uuBytes_test([1, 2, 3])
    }
    
    func test_uuBytes_minMax()
    {
        do_uuBytes_test([00, 0xFF, 00, 0xFF])
    }
    
    // MARK: uuData(at:count)
    
    private func do_uuDataAtIndex_text(_ bytes: [UInt8], index: Int, count: Int, expected: [UInt8]?)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuData(at: index, count: count)
        
        if (expected == nil)
        {
            XCTAssertNil(actual)
        }
        else
        {
            let actualBytes = actual?.uuBytes
            XCTAssertNotNil(actualBytes)
            XCTAssertEqual(actualBytes, expected)
        }
    }
    
    func test_uuDataAtIndex_empty()
    {
        do_uuDataAtIndex_text([], index: 0, count: 0, expected: [])
    }
    
    func test_uuDataAtIndex_negativeIndex()
    {
        do_uuDataAtIndex_text([1, 2, 3], index: -1, count: 0, expected: nil)
    }
    
    func test_uuDataAtIndex_indexOutOfBounds()
    {
        do_uuDataAtIndex_text([1, 2, 3], index: 24, count: 1, expected: nil)
    }
    
    func test_uuDataAtIndex_negativeCount()
    {
        do_uuDataAtIndex_text([1, 2, 3], index: 0, count: -1, expected: nil)
    }
    
    func test_uuDataAtIndex_zeroCount()
    {
        do_uuDataAtIndex_text([1, 2, 3], index: 0, count: 0, expected: [])
    }
    
    func test_uuDataAtIndex_single()
    {
        do_uuDataAtIndex_text([1, 2, 3], index: 0, count: 1, expected: [1])
        do_uuDataAtIndex_text([1, 2, 3], index: 1, count: 1, expected: [2])
        do_uuDataAtIndex_text([1, 2, 3], index: 2, count: 1, expected: [3])
    }
    
    func test_uuDataAtIndex_countTooLong()
    {
        do_uuDataAtIndex_text([1, 2, 3], index: 0, count: 8, expected: [1, 2, 3])
        do_uuDataAtIndex_text([1, 2, 3], index: 1, count: 8, expected: [2, 3])
    }
    
    func test_uuDataAtIndex_multiple()
    {
        do_uuDataAtIndex_text([0xDE, 0xAD, 0xBE, 0xEF], index: 1, count: 2, expected: [0xAD, 0xBE])
    }
    
    // MARK: uuSafeData(at:count)
    
    private func do_uuSafeDataAtIndex_text(_ bytes: [UInt8], index: Int, count: Int, expected: [UInt8])
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuSafeData(at: index, count: count)
        XCTAssertEqual(actual.uuBytes, expected)
    }
    
    func test_uuSafeDataAtIndex_empty()
    {
        do_uuSafeDataAtIndex_text([], index: 0, count: 0, expected: [])
    }
    
    func test_uuSafeDataAtIndex_negativeIndex()
    {
        do_uuSafeDataAtIndex_text([1, 2, 3], index: -1, count: 0, expected: [])
    }
    
    func test_uuSafeDataAtIndex_negativeCount()
    {
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 0, count: -1, expected: [])
    }
    
    func test_uuSafeDataAtIndex_indexOutOfBounds()
    {
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 22, count: 1, expected: [])
    }
    
    func test_uuSafeDataAtIndex_single()
    {
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 0, count: 1, expected: [1])
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 1, count: 1, expected: [2])
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 2, count: 1, expected: [3])
    }
    
    func test_uuSafeDataAtIndex_countTooLong()
    {
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 0, count: 8, expected: [1, 2, 3])
        do_uuSafeDataAtIndex_text([1, 2, 3], index: 1, count: 8, expected: [2, 3])
    }
    
    func test_uuSafeDataAtIndex_multiple()
    {
        do_uuSafeDataAtIndex_text([0xDE, 0xAD, 0xBE, 0xEF], index: 1, count: 2, expected: [0xAD, 0xBE])
    }
    
    // MARK: uuInteger(at:count)
    
    private func do_uuIntegerAtIndex_testNil(_ bytes: [UInt8], index: Int)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual: Int? = input.uuInteger(at: index)
        XCTAssertNil(actual)
    }
    
    private func do_uuIntegerAtIndex_test<T: FixedWidthInteger>(_ bytes: [UInt8], index: Int, expected: T)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual: T? = input.uuInteger(at: index)
        XCTAssertNotNil(actual)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuIntegerAtIndex()
    {
        do_uuIntegerAtIndex_testNil([], index: 0)
        do_uuIntegerAtIndex_testNil([1, 2, 3], index: 10)
        
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF]
        do_uuIntegerAtIndex_test(bytes, index: 0, expected: UInt8(0x00))
        do_uuIntegerAtIndex_test(bytes, index: 4, expected: UInt8(0x04))
        do_uuIntegerAtIndex_test(bytes, index: 11, expected: UInt8(0xB))
        
        do_uuIntegerAtIndex_test(bytes, index: 0, expected: UInt16(0x0100))
        do_uuIntegerAtIndex_test(bytes, index: 4, expected: UInt16(0x0504))
        do_uuIntegerAtIndex_test(bytes, index: 11, expected: UInt16(0x0C0B))
        
        do_uuIntegerAtIndex_test(bytes, index: 0, expected: UInt32(0x03020100))
        do_uuIntegerAtIndex_test(bytes, index: 4, expected: UInt32(0x07060504))
        do_uuIntegerAtIndex_test(bytes, index: 11, expected: UInt32(0x0E0D0C0B))
        
        do_uuIntegerAtIndex_test(bytes, index: 3, expected: UInt64(0x0A09080706050403))
        
        // If the bytes do not have enough to populate the value
        do_uuIntegerAtIndex_testNil(bytes, index: 14)
    }
    
    // MARK: uuUInt8(at:count)
    
    private func do_uuUInt8AtIndex_test(_ bytes: [UInt8], index: Int, expected: UInt8)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt8(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt8AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0x7F, 0x80]
        do_uuUInt8AtIndex_test(bytes, index: 0, expected: 0)
        do_uuUInt8AtIndex_test(bytes, index: 1, expected: 1)
        do_uuUInt8AtIndex_test(bytes, index: 2, expected: 2)
        do_uuUInt8AtIndex_test(bytes, index: 15, expected: 0x0F)
        do_uuUInt8AtIndex_test(bytes, index: 10, expected: 0x0A)
        do_uuUInt8AtIndex_test(bytes, index: 16, expected: 0xFF)
        do_uuUInt8AtIndex_test(bytes, index: 17, expected: 0x7F)
        do_uuUInt8AtIndex_test(bytes, index: 18, expected: 0x80)
    }
    
    // MARK: uuUInt16(at:count)
    
    private func do_uuUInt16AtIndex_test(_ bytes: [UInt8], index: Int, expected: UInt16)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt16(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt16AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x80]
        do_uuUInt16AtIndex_test(bytes, index: 0, expected: 0x0100)
        do_uuUInt16AtIndex_test(bytes, index: 1, expected: 0x0201)
        do_uuUInt16AtIndex_test(bytes, index: 2, expected: 0x0302)
        do_uuUInt16AtIndex_test(bytes, index: 14, expected: 0x0F0E)
        do_uuUInt16AtIndex_test(bytes, index: 10, expected: 0x0B0A)
        do_uuUInt16AtIndex_test(bytes, index: 16, expected: 0xFFFF)
        do_uuUInt16AtIndex_test(bytes, index: 18, expected: 0x7FFF)
        do_uuUInt16AtIndex_test(bytes, index: 20, expected: 0x8000)
    }
    
    // MARK: uuUInt32(at:count)
    
    private func do_uuUInt32AtIndex_test(_ bytes: [UInt8], index: Int, expected: UInt32)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt32(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt32AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x80]
        do_uuUInt32AtIndex_test(bytes, index: 0, expected: 0x03020100)
        do_uuUInt32AtIndex_test(bytes, index: 1, expected: 0x04030201)
        do_uuUInt32AtIndex_test(bytes, index: 2, expected: 0x05040302)
        do_uuUInt32AtIndex_test(bytes, index: 12, expected: 0x0F0E0D0C)
        do_uuUInt32AtIndex_test(bytes, index: 10, expected: 0x0D0C0B0A)
        do_uuUInt32AtIndex_test(bytes, index: 16, expected: 0xFFFFFFFF)
        do_uuUInt32AtIndex_test(bytes, index: 20, expected: 0x7FFFFFFF)
        do_uuUInt32AtIndex_test(bytes, index: 24, expected: 0x80000000)
    }
    
    // MARK: uuUInt64(at:count)
    
    private func do_uuUInt64AtIndex_test(_ bytes: [UInt8], index: Int, expected: UInt64)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt64(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt64AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]
        do_uuUInt64AtIndex_test(bytes, index: 0, expected: 0x0706050403020100)
        do_uuUInt64AtIndex_test(bytes, index: 1, expected: 0x0807060504030201)
        do_uuUInt64AtIndex_test(bytes, index: 2, expected: 0x0908070605040302)
        do_uuUInt64AtIndex_test(bytes, index: 8, expected: 0x0F0E0D0C0B0A0908)
        do_uuUInt64AtIndex_test(bytes, index: 16, expected: 0xFFFFFFFFFFFFFFFF)
        do_uuUInt64AtIndex_test(bytes, index: 24, expected: 0x7FFFFFFFFFFFFFFF)
        do_uuUInt64AtIndex_test(bytes, index: 32, expected: 0x8000000000000000)
    }
    
    // MARK: uuInt8(at:count)
    
    private func do_uuInt8AtIndex_test(_ bytes: [UInt8], index: Int, expected: Int8)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt8(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt8AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0x7F, 0x80]
        do_uuInt8AtIndex_test(bytes, index: 0, expected: 0)
        do_uuInt8AtIndex_test(bytes, index: 1, expected: 1)
        do_uuInt8AtIndex_test(bytes, index: 2, expected: 2)
        do_uuInt8AtIndex_test(bytes, index: 15, expected: 0x0F)
        do_uuInt8AtIndex_test(bytes, index: 10, expected: 0x0A)
        do_uuInt8AtIndex_test(bytes, index: 16, expected: -1)
        do_uuInt8AtIndex_test(bytes, index: 17, expected: Int8.max)
        do_uuInt8AtIndex_test(bytes, index: 18, expected: Int8.min)
    }
    
    // MARK: uuInt16(at:count)
    
    private func do_uuInt16AtIndex_test(_ bytes: [UInt8], index: Int, expected: Int16)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt16(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt16AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x80]
        do_uuInt16AtIndex_test(bytes, index: 0, expected: 0x0100)
        do_uuInt16AtIndex_test(bytes, index: 1, expected: 0x0201)
        do_uuInt16AtIndex_test(bytes, index: 2, expected: 0x0302)
        do_uuInt16AtIndex_test(bytes, index: 14, expected: 0x0F0E)
        do_uuInt16AtIndex_test(bytes, index: 10, expected: 0x0B0A)
        do_uuInt16AtIndex_test(bytes, index: 16, expected: -1)
        do_uuInt16AtIndex_test(bytes, index: 18, expected: Int16.max)
        do_uuInt16AtIndex_test(bytes, index: 20, expected: Int16.min)
    }
    
    // MARK: uuInt32(at:count)
    
    private func do_uuInt32AtIndex_test(_ bytes: [UInt8], index: Int, expected: Int32)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt32(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt32AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x80]
        do_uuInt32AtIndex_test(bytes, index: 0, expected: 0x03020100)
        do_uuInt32AtIndex_test(bytes, index: 1, expected: 0x04030201)
        do_uuInt32AtIndex_test(bytes, index: 2, expected: 0x05040302)
        do_uuInt32AtIndex_test(bytes, index: 12, expected: 0x0F0E0D0C)
        do_uuInt32AtIndex_test(bytes, index: 10, expected: 0x0D0C0B0A)
        do_uuInt32AtIndex_test(bytes, index: 16, expected: -1)
        do_uuInt32AtIndex_test(bytes, index: 20, expected: Int32.max)
        do_uuInt32AtIndex_test(bytes, index: 24, expected: Int32.min)
    }
    
    // MARK: uuInt64(at:count)
    
    private func do_uuInt64AtIndex_test(_ bytes: [UInt8], index: Int, expected: Int64)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt64(at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt64AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]
        do_uuInt64AtIndex_test(bytes, index: 0, expected: 0x0706050403020100)
        do_uuInt64AtIndex_test(bytes, index: 1, expected: 0x0807060504030201)
        do_uuInt64AtIndex_test(bytes, index: 2, expected: 0x0908070605040302)
        do_uuInt64AtIndex_test(bytes, index: 8, expected: 0x0F0E0D0C0B0A0908)
        do_uuInt64AtIndex_test(bytes, index: 16, expected: -1)
        do_uuInt64AtIndex_test(bytes, index: 24, expected: Int64.max)
        do_uuInt64AtIndex_test(bytes, index: 32, expected: Int64.min)
    }
    
    // MARK: uuString(at:count:with)
    
    private func do_uuStringAtIndex_test(_ bytes: [UInt8], index: Int, count: Int, encoding: String.Encoding, expected: String)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuString(at: index, count: count, with: encoding)
        XCTAssertNotNil(actual)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuStringAtIndex()
    {
        let bytes: [UInt8] = [ 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x41, 0x42, 0x43, 0x44 ]
        do_uuStringAtIndex_test(bytes, index: 0, count: 2, encoding: .ascii, expected: "01")
        do_uuStringAtIndex_test(bytes, index: 0, count: bytes.count, encoding: .ascii, expected: "0123456ABCD")
        do_uuStringAtIndex_test(bytes, index: 4, count: 5, encoding: .ascii, expected: "456AB")
    }
    
    // MARK: uuAppend(integers)
    
    private func do_uuAppendInteger_test<T: FixedWidthInteger>(_ existing: Data, data: T, expected: [UInt8])
    {
        var input = existing.uuData(at: 0, count: existing.count) // Make a copy
        XCTAssertNotNil(input)
        
        let countBefore = input!.count
        input!.uuAppend(data)
        let countAfter = input!.count
        
        XCTAssertEqual(countAfter - countBefore, MemoryLayout<T>.size)
        XCTAssertEqual(input!.uuBytes, expected)
    }
    
    func test_uuAppendInteger()
    {
        let data = Data()
        
        do_uuAppendInteger_test(data, data: UInt8(22), expected: [ 22 ])
        do_uuAppendInteger_test(data, data: UInt8(57), expected: [ 57 ])
        do_uuAppendInteger_test(data, data: UInt8.min, expected: [ 0x00 ])
        do_uuAppendInteger_test(data, data: UInt8.max, expected: [ 0xFF ])
        
        do_uuAppendInteger_test(data, data: UInt16(0), expected: [ 0, 0 ])
        do_uuAppendInteger_test(data, data: UInt16(0x00FF), expected: [ 0xFF, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt16(0x00FF).bigEndian, expected: [ 0x00, 0xFF ])
        do_uuAppendInteger_test(data, data: UInt16(57), expected: [ 57, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt16(0xABCD), expected: [ 0xCD, 0xAB ])
        do_uuAppendInteger_test(data, data: UInt16.min, expected: [ 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt16.max, expected: [ 0xFF, 0xFF ])
        
        do_uuAppendInteger_test(data, data: UInt32(0), expected: [ 0, 0, 0, 0 ])
        do_uuAppendInteger_test(data, data: UInt32(0x00FF), expected: [ 0xFF, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt32(0x00FF).bigEndian, expected: [ 0x00, 0x00, 0x00, 0xFF ])
        do_uuAppendInteger_test(data, data: UInt32(57), expected: [ 57, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt32(0xABCD1234), expected: [ 0x34, 0x12, 0xCD, 0xAB ])
        do_uuAppendInteger_test(data, data: UInt32.min, expected: [ 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt32.max, expected: [ 0xFF, 0xFF, 0xFF, 0xFF ])
        
        do_uuAppendInteger_test(data, data: UInt64(0), expected: [ 0, 0, 0, 0, 0, 0, 0, 0 ])
        do_uuAppendInteger_test(data, data: UInt64(0x00FF), expected: [ 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt64(0x00FF).bigEndian, expected: [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF ])
        do_uuAppendInteger_test(data, data: UInt64(57), expected: [ 57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt64(0xABCD1234), expected: [ 0x34, 0x12, 0xCD, 0xAB, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt64.min, expected: [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: UInt64.max, expected: [ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF ])
        
        do_uuAppendInteger_test(data, data: Int8(22), expected: [ 22 ])
        do_uuAppendInteger_test(data, data: Int8(57), expected: [ 57 ])
        do_uuAppendInteger_test(data, data: Int8.min, expected: [ 0x80 ])
        do_uuAppendInteger_test(data, data: Int8.max, expected: [ 0x7F ])
        
        do_uuAppendInteger_test(data, data: Int16(0), expected: [ 0, 0 ])
        do_uuAppendInteger_test(data, data: Int16(0x00FF), expected: [ 0xFF, 0x00 ])
        do_uuAppendInteger_test(data, data: Int16(0x00FF).bigEndian, expected: [ 0x00, 0xFF ])
        do_uuAppendInteger_test(data, data: Int16(57), expected: [ 57, 0x00 ])
        do_uuAppendInteger_test(data, data: Int16(0x1234), expected: [ 0x34, 0x12 ])
        do_uuAppendInteger_test(data, data: Int16.min, expected: [ 0x00, 0x80 ])
        do_uuAppendInteger_test(data, data: Int16.max, expected: [ 0xFF, 0x7F ])
        
        do_uuAppendInteger_test(data, data: Int32(0), expected: [ 0, 0, 0, 0 ])
        do_uuAppendInteger_test(data, data: Int32(0x00FF), expected: [ 0xFF, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: Int32(0x00FF).bigEndian, expected: [ 0x00, 0x00, 0x00, 0xFF ])
        do_uuAppendInteger_test(data, data: Int32(57), expected: [ 57, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: Int32(0x12345678), expected: [ 0x78, 0x56, 0x34, 0x12 ])
        do_uuAppendInteger_test(data, data: Int32.min, expected: [ 0x00, 0x00, 0x00, 0x80 ])
        do_uuAppendInteger_test(data, data: Int32.max, expected: [ 0xFF, 0xFF, 0xFF, 0x7F ])
        
        do_uuAppendInteger_test(data, data: Int64(0), expected: [ 0, 0, 0, 0, 0, 0, 0, 0 ])
        do_uuAppendInteger_test(data, data: Int64(0x00FF), expected: [ 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: Int64(0x00FF).bigEndian, expected: [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF ])
        do_uuAppendInteger_test(data, data: Int64(57), expected: [ 57, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: Int64(0xABCD1234), expected: [ 0x34, 0x12, 0xCD, 0xAB, 0x00, 0x00, 0x00, 0x00 ])
        do_uuAppendInteger_test(data, data: Int64.min, expected: [ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80 ])
        do_uuAppendInteger_test(data, data: Int64.max, expected: [ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F ])
    }
}
