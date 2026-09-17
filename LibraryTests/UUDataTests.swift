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
    
    private func do_uuIntegerAtIndex_testNil(_ order: UUByteOrder, _ bytes: [UInt8], index: Int)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual: Int? = input.uuInteger(order: order, at: index)
        XCTAssertNil(actual)
    }
    
    private func do_uuIntegerAtIndex_test<T: FixedWidthInteger>(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: T)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual: T? = input.uuInteger(order: order, at: index)
        XCTAssertNotNil(actual)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuIntegerAtIndex()
    {
        do_uuIntegerAtIndex_testNil(.littleEndian, [], index: 0)
        do_uuIntegerAtIndex_testNil(.littleEndian, [1, 2, 3], index: 10)
        do_uuIntegerAtIndex_testNil(.bigEndian, [], index: 0)
        do_uuIntegerAtIndex_testNil(.bigEndian, [1, 2, 3], index: 10)
        
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF]
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 0, expected: UInt8(0x00))
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 4, expected: UInt8(0x04))
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 11, expected: UInt8(0xB))
        
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 0, expected: UInt16(0x0100))
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 4, expected: UInt16(0x0504))
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 11, expected: UInt16(0x0C0B))
        
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 0, expected: UInt32(0x03020100))
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 4, expected: UInt32(0x07060504))
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 11, expected: UInt32(0x0E0D0C0B))
        
        do_uuIntegerAtIndex_test(.littleEndian, bytes, index: 3, expected: UInt64(0x0A09080706050403))
        
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 0, expected: UInt8(0x00))
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 4, expected: UInt8(0x04))
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 11, expected: UInt8(0xB))
        
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 0, expected: UInt16(0x0001))
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 4, expected: UInt16(0x0405))
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 11, expected: UInt16(0x0B0C))
        
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 0, expected: UInt32(0x00010203))
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 4, expected: UInt32(0x04050607))
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 11, expected: UInt32(0x0B0C0D0E))
        
        do_uuIntegerAtIndex_test(.bigEndian, bytes, index: 3, expected: UInt64(0x030405060708090A))
        
        // If the bytes do not have enough to populate the value
        do_uuIntegerAtIndex_testNil(.littleEndian, bytes, index: 14)
        do_uuIntegerAtIndex_testNil(.bigEndian, bytes, index: 14)
    }
    
    // MARK: uuUInt8(at:)
    
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
    
    private func do_uuUInt16AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: UInt16)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt16(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt16AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x80]
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x0100)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x0201)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x0302)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 14, expected: 0x0F0E)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 10, expected: 0x0B0A)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 16, expected: 0xFFFF)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 18, expected: 0x7FFF)
        do_uuUInt16AtIndex_test(.littleEndian, bytes, index: 20, expected: 0x8000)
        
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x0001)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x0102)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x0203)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 14, expected: 0x0E0F)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 10, expected: 0x0A0B)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 16, expected: 0xFFFF)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 18, expected: 0xFF7F)
        do_uuUInt16AtIndex_test(.bigEndian, bytes, index: 20, expected: 0x0080)
    }
    
    // MARK: uuUInt24(at:count)
    
    private func do_uuUInt24AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: UInt32)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt24(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt24AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x80]
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x020100)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x030201)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x040302)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 14, expected: 0xFF0F0E)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 10, expected: 0x0C0B0A)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 16, expected: 0xFFFFFF)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 18, expected: 0x007FFF)
        do_uuUInt24AtIndex_test(.littleEndian, bytes, index: 19, expected: 0x80007F)
        
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x000102)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x010203)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x020304)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 14, expected: 0x0E0FFF)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 10, expected: 0x0A0B0C)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 16, expected: 0xFFFFFF)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 18, expected: 0xFF7F00)
        do_uuUInt24AtIndex_test(.bigEndian, bytes, index: 19, expected: 0x7F0080)
    }
    
    // MARK: uuUInt32(at:count)
    
    private func do_uuUInt32AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: UInt32)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt32(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt32AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x80]
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x03020100)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x04030201)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x05040302)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 12, expected: 0x0F0E0D0C)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 10, expected: 0x0D0C0B0A)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 16, expected: 0xFFFFFFFF)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 20, expected: 0x7FFFFFFF)
        do_uuUInt32AtIndex_test(.littleEndian, bytes, index: 24, expected: 0x80000000)
        
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x00010203)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x01020304)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x02030405)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 12, expected: 0x0C0D0E0F)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 10, expected: 0x0A0B0C0D)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 16, expected: 0xFFFFFFFF)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 20, expected: 0xFFFFFF7F)
        do_uuUInt32AtIndex_test(.bigEndian, bytes, index: 24, expected: 0x00000080)
    }
    
    // MARK: uuUInt64(at:count)
    
    private func do_uuUInt64AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: UInt64)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuUInt64(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuUInt64AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x0706050403020100)
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x0807060504030201)
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x0908070605040302)
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 8, expected: 0x0F0E0D0C0B0A0908)
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 16, expected: 0xFFFFFFFFFFFFFFFF)
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 24, expected: 0x7FFFFFFFFFFFFFFF)
        do_uuUInt64AtIndex_test(.littleEndian, bytes, index: 32, expected: 0x8000000000000000)
        
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x0001020304050607)
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x0102030405060708)
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x0203040506070809)
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 8, expected: 0x08090A0B0C0D0E0F)
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 16, expected: 0xFFFFFFFFFFFFFFFF)
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 24, expected: 0xFFFFFFFFFFFFFF7F)
        do_uuUInt64AtIndex_test(.bigEndian, bytes, index: 32, expected: 0x0000000000000080)
    }
    
    // MARK: uuInt8(at:)
    
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
    
    private func do_uuInt16AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: Int16)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt16(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt16AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x80]
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x0100)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x0201)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x0302)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 14, expected: 0x0F0E)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 10, expected: 0x0B0A)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 16, expected: -1)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 18, expected: Int16.max)
        do_uuInt16AtIndex_test(.littleEndian, bytes, index: 20, expected: Int16.min)
        
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x0001)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x0102)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x0203)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 14, expected: 0x0E0F)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 10, expected: 0x0A0B)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 16, expected: -1)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 18, expected: -129)
        do_uuInt16AtIndex_test(.bigEndian, bytes, index: 20, expected: 128)
    }
    
    // MARK: uuInt32(at:count)
    
    private func do_uuInt32AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: Int32)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt32(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt32AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x80]
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x03020100)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x04030201)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x05040302)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 12, expected: 0x0F0E0D0C)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 10, expected: 0x0D0C0B0A)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 16, expected: -1)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 20, expected: Int32.max)
        do_uuInt32AtIndex_test(.littleEndian, bytes, index: 24, expected: Int32.min)
        
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x00010203)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x01020304)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x02030405)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 12, expected: 0x0C0D0E0F)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 10, expected: 0x0A0B0C0D)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 16, expected: -1)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 20, expected: -129)
        do_uuInt32AtIndex_test(.bigEndian, bytes, index: 24, expected: 128)
    }
    
    // MARK: uuInt64(at:count)
    
    private func do_uuInt64AtIndex_test(_ order: UUByteOrder, _ bytes: [UInt8], index: Int, expected: Int64)
    {
        let input = Data(bytes: bytes, count: bytes.count)
        let actual = input.uuInt64(order: order, at: index)
        XCTAssertEqual(actual, expected)
    }
    
    func test_uuInt64AtIndex()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 0, expected: 0x0706050403020100)
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 1, expected: 0x0807060504030201)
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 2, expected: 0x0908070605040302)
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 8, expected: 0x0F0E0D0C0B0A0908)
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 16, expected: -1)
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 24, expected: Int64.max)
        do_uuInt64AtIndex_test(.littleEndian, bytes, index: 32, expected: Int64.min)
        
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 0, expected: 0x0001020304050607)
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 1, expected: 0x0102030405060708)
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 2, expected: 0x0203040506070809)
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 8, expected: 0x08090A0B0C0D0E0F)
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 16, expected: -1)
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 24, expected: -129)
        do_uuInt64AtIndex_test(.bigEndian, bytes, index: 32, expected: 128)
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
    
    // MARK: uuAppend(string)
    
    
    private func do_uuAppendString_test(_ existing: Data, data: String, encoding: String.Encoding, expected: [UInt8])
    {
        var input = existing.uuData(at: 0, count: existing.count) // Make a copy
        XCTAssertNotNil(input)
        
        let countBefore = input!.count
        input!.uuAppend(data, encoding: encoding)
        let countAfter = input!.count
        
        XCTAssertEqual(countAfter - countBefore, data.data(using: encoding)?.count)
        XCTAssertEqual(input!.uuBytes, expected)
    }
    
    func test_uuAppendString()
    {
        let data = Data()
        
        do_uuAppendString_test(data, data: "Hello World", encoding: .utf8, expected: [ 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F, 0x72, 0x6C, 0x64])
        do_uuAppendString_test(data, data: "1234", encoding: .utf8, expected: [ 0x31, 0x32, 0x33, 0x34 ])
    }
    
    // MARK: uuReplace(integer)
    
    private func do_uuReplaceInteger_test<T: FixedWidthInteger>(_ bytes: [UInt8], data: T, index: Int, expected: [UInt8])
    {
        var input = Data(bytes: bytes, count: bytes.count)
        XCTAssertNotNil(input)
        
        let countBefore = input.count
        input.uuReplace(data, at: index)
        let countAfter = input.count
        
        XCTAssertEqual(countAfter, countBefore)
        XCTAssertEqual(input.uuBytes, expected)
    }
    
    func test_uuReplaceInteger()
    {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF]
        
        do_uuReplaceInteger_test(bytes, data: UInt8(57), index: 3, expected: [0, 1, 2, 57, 4, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF])
        do_uuReplaceInteger_test(bytes, data: UInt16(57), index: 3, expected: [0, 1, 2, 57, 0, 5, 6, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF])
        do_uuReplaceInteger_test(bytes, data: UInt32(57), index: 3, expected: [0, 1, 2, 57, 0, 0, 0, 7, 8, 9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF])
        do_uuReplaceInteger_test(bytes, data: UInt64(57), index: 3, expected: [0, 1, 2, 57, 0, 0, 0, 0, 0, 0, 0, 0xB, 0xC, 0xD, 0xE, 0xF])
    }
    
    // MARK: Nibble Tests
    
    func test_uuHighNibble()
    {
        let testData: [(String, UInt8)] =
        [
            ("00", 0),
            ("12", 1),
            ("01", 0),
            ("99", 9),
            ("CB", 0xC),
            ("57abcd1234", 5),
            ("FF", 0xF),
        ]
        
        for td in testData
        {
            let data = td.0.uuToHexData() as Data?
            XCTAssertNotNil(data)
            
            let actual = data!.uuHighNibble(at: 0)
            XCTAssertEqual(td.1, actual)
        }
    }
    
    func test_uuLowNibble()
    {
        let testData: [(String, UInt8)] =
        [
            ("00", 0),
            ("12", 2),
            ("01", 1),
            ("99", 9),
            ("CB", 0xB),
            ("57abcd1234", 7),
            ("FF", 0xF),
        ]
        
        for td in testData
        {
            let data = td.0.uuToHexData() as Data?
            XCTAssertNotNil(data)
            
            let actual = data!.uuLowNibble(at: 0)
            XCTAssertEqual(td.1, actual)
        }
    }
    
    // MARK: uuBCDX
    
    func test_uuBCD8()
    {
        let testData: [(String, UInt8?)] =
        [
            ("00", 0),
            ("12", 12),
            ("01", 1),
            ("99", 99),
            ("57abcd1234", 57),
            ("FF", nil),
        ]
        
        for td in testData
        {
            let data = td.0.uuToHexData() as Data?
            XCTAssertNotNil(data)
            
            let actual = data!.uuBCD8(at: 0)
            
            if (td.1 != nil)
            {
                XCTAssertNotNil(actual)
                XCTAssertEqual(td.1, actual)
            }
            else
            {
                XCTAssertNil(actual)
            }
        }
    }
    
    func test_uuBCD16()
    {
        let testData: [(String, UInt16?)] =
        [
            ("0000", 0),
            ("1234", 1234),
            ("0101", 101),
            ("9999", 9999),
            ("FFFF", nil),
            ("12", nil), // Not enough bytes for a UInt16
            ("1234ABCD", 1234)
        ]
        
        for td in testData
        {
            let data = td.0.uuToHexData() as Data?
            XCTAssertNotNil(data)
            
            let actual = data!.uuBCD16(at: 0)
            
            if (td.1 != nil)
            {
                XCTAssertEqual(td.1, actual)
            }
            else
            {
                XCTAssertNil(actual)
            }
        }
    }
    
    func test_uuBCD24()
    {
        let testData: [(String, UInt32?)] =
        [
            ("000000", 0),
            ("123456", 123456),
            ("010101", 10101),
            ("999999", 999999),
            ("FFFFFF", nil),
            ("1234", nil), // Not enough bytes for a UInt24
            ("123456ABCD", 123456)
        ]
        
        for td in testData
        {
            let data = td.0.uuToHexData() as Data?
            XCTAssertNotNil(data)
            
            let actual = data!.uuBCD24(at: 0)
            
            if (td.1 != nil)
            {
                XCTAssertEqual(td.1, actual)
            }
            else
            {
                XCTAssertNil(actual)
            }
        }
    }
    
    func test_uuBCD32()
    {
        let testData: [(String, UInt32?)] =
        [
            ("00000000", 0),
            ("12345678", 12345678),
            ("01010101", 1010101),
            ("99999999", 99999999),
            ("FFFFFFFF", nil),
            ("123456", nil), // Not enough bytes for a UInt24
            ("12345678ABCD", 12345678)
        ]
        
        for td in testData
        {
            let data = td.0.uuToHexData() as Data?
            XCTAssertNotNil(data)
            
            let actual = data!.uuBCD32(at: 0)
            
            if (td.1 != nil)
            {
                XCTAssertEqual(td.1, actual)
            }
            else
            {
                XCTAssertNil(actual)
            }
        }
    }
    
    func test_uuSlice()
    {
        let testData: [(String,Int,[String])] =
        [
            ("112233445566", 2, ["1122", "3344", "5566"]),
            ("11223344556677", 2, ["1122", "3344", "5566", "77"]),
            ("112233445566", 20, ["112233445566"])
        ]
        
        for td in testData
        {
            let input = td.0.uuToHexData() as Data?
            XCTAssertNotNil(input)
            
            let actual = input!.uuSlice(chunkSize: td.1)
            let actualHex = actual.compactMap({ $0.uuToHexString() })
            XCTAssertEqual(td.2, actualHex)
        }
    }
    
    func test_uuPadded() throws
    {
        let testData: [(String,Int,String)] =
        [
            ("1122", 4, "11220000"),
            ("1122", 2, "1122"),
            ("1122", 1, "11"),
        ]
        
        for td in testData
        {
            let input = try XCTUnwrap(td.0.uuToHexData() as Data?)
            
            let actual = input.uuPadded(toLength: td.1)
            let actualHex = actual.uuToHexString()
            XCTAssertEqual(td.2, actualHex)
        }
    }
    
    func test_uuPaddedToBlockSize() throws
    {
        let testData: [(String,Int,String)] =
        [
            ("1122", 8, "1122000000000000"),
            ("1122", 2, "1122"),
            ("1122", 7, "11220000000000"),
        ]
        
        for td in testData
        {
            let input = try XCTUnwrap(td.0.uuToHexData() as Data?)
            
            let actual = input.uuPadded(toBlockSize: td.1)
            let actualHex = actual.uuToHexString()
            XCTAssertEqual(td.2, actualHex)
        }
    }
    
    func test_uuXor() throws
    {
        let testData: [(String,String,String)] =
        [
            ("1122", "0000", "1122"),
            ("1122", "FFFF", "EEDD"),
            ("1122", "22",   "1122"),
            ("1122", "223344", "1122"),
            ("5050", "0707", "5757"),
        ]
        
        for td in testData
        {
            let inputA = try XCTUnwrap(td.0.uuToHexData() as Data?)
            let inputB = try XCTUnwrap(td.1.uuToHexData() as Data?)
            
            let actual = inputA.uuXor(with: inputB)
            let actualHex = actual.uuToHexString()
            XCTAssertEqual(td.2, actualHex)
        }
    }
    
    func test_uuReset() throws
    {
        let testData: [(String,String)] =
        [
            ("1122", "0000"),
            ("abcdef", "000000")
        ]
        
        for td in testData
        {
            var input = try XCTUnwrap(td.0.uuToHexData() as Data?)
            
            input.uuReset()
            let actualHex = input.uuToHexString()
            XCTAssertEqual(td.1, actualHex)
        }
        
    }
    
    func test_uuSetAll() throws
    {
        let testData: [(String, UInt8, String)] =
        [
            ("1122", UInt8(0x57), "5757"),
            ("abcdef", UInt8(0), "000000"),
            ("abcdef", UInt8(0xA), "0A0A0A")
        ]
        
        for td in testData
        {
            var input = try XCTUnwrap(td.0.uuToHexData() as Data?)
            
            input.uuSetAll(to: td.1)
            let actualHex = input.uuToHexString()
            XCTAssertEqual(td.2, actualHex)
        }
    }

    // MARK: - uuSha256 / uuSha384 / uuSha512

    private func assertShaDigest(
        _ input: Data,
        expectedHex: String,
        expectedLength: Int,
        digest: (Data) -> Data)
    {
        let actual = digest(input)
        XCTAssertEqual(actual.count, expectedLength)
        XCTAssertEqual(actual.uuToHexString(), expectedHex)
    }

    func test_uuSha256_empty()
    {
        assertShaDigest(
            Data(),
            expectedHex: "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855",
            expectedLength: 32,
            digest: { $0.uuSha256() })
    }

    func test_uuSha256_abc()
    {
        assertShaDigest(
            Data("abc".utf8),
            expectedHex: "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
            expectedLength: 32,
            digest: { $0.uuSha256() })
    }

    func test_uuSha384_empty()
    {
        assertShaDigest(
            Data(),
            expectedHex: "38B060A751AC96384CD9327EB1B1E36A21FDB71114BE07434C0CC7BF63F6E1DA274EDEBFE76F65FBD51AD2F14898B95B",
            expectedLength: 48,
            digest: { $0.uuSha384() })
    }

    func test_uuSha384_abc()
    {
        assertShaDigest(
            Data("abc".utf8),
            expectedHex: "CB00753F45A35E8BB5A03D699AC65007272C32AB0EDED1631A8B605A43FF5BED8086072BA1E7CC2358BAECA134C825A7",
            expectedLength: 48,
            digest: { $0.uuSha384() })
    }

    func test_uuSha512_empty()
    {
        assertShaDigest(
            Data(),
            expectedHex: "CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E",
            expectedLength: 64,
            digest: { $0.uuSha512() })
    }

    func test_uuSha512_abc()
    {
        assertShaDigest(
            Data("abc".utf8),
            expectedHex: "DDAF35A193617ABACC417349AE20413112E6FA4E89A97EA20A9EEEE64B55D39A2192992A274FC1A836BA3C23A3FEEBBD454D4423643CE80E2A9AC94FA54CA49F",
            expectedLength: 64,
            digest: { $0.uuSha512() })
    }

    // MARK: Additional boundary and regression coverage

    func test_uuDataAtIndex_endBoundaries()
    {
        for input in [Data(), Data([1, 2, 3])]
        {
            XCTAssertEqual(input.uuData(at: input.count, count: 0), Data())
            XCTAssertEqual(input.uuData(at: input.count, count: 5), Data())
            XCTAssertNil(input.uuData(at: input.count + 1, count: 0))
            XCTAssertEqual(input.uuSafeData(at: input.count, count: 5), Data())
        }
    }

    func test_uuDataAtIndex_overflowingCount() throws
    {
        XCTAssertEqual(Data([1, 2, 3]).uuData(at: 1, count: Int.max), Data([2, 3]))
    }

    func test_uuDataAtIndex_overflowingIndex() throws
    {
        XCTAssertNil(Data([1]).uuData(at: Int.max, count: 1))
        XCTAssertEqual(Data([1]).uuSafeData(at: Int.max, count: 1), Data())
    }

    func test_uuUInt24AtIndex_shortInput() throws
    {
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data([1]), Data([1, 2]), Data([1, 2, 3])]
            {
                for index in 0...input.count where input.count - index < 3
                {
                    XCTAssertNil(input.uuUInt24(order: order, at: index))
                }
            }
        }
    }

    func test_uuUInt24AtIndex_invalidIndicesAndLimits()
    {
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            XCTAssertNil(Data([1, 2, 3]).uuUInt24(order: order, at: -1))
            XCTAssertNil(Data([1, 2, 3]).uuUInt24(order: order, at: 4))
            XCTAssertEqual(Data([0, 0, 0]).uuUInt24(order: order, at: 0), 0)
            XCTAssertEqual(Data([255, 255, 255]).uuUInt24(order: order, at: 0), 0xFFFFFF)
        }
    }

    func test_uuUInt8_boundariesAndSafeDefaults()
    {
        for input in [Data(), Data([0])]
        {
            for index in [-1, 0, input.count, input.count + 1]
            {
                let valid = index == 0 && !input.isEmpty
                let expected: UInt8? = valid ? 0 : nil
                XCTAssertEqual(input.uuUInt8(at: index), expected, "index: \(index), count: \(input.count)")
                XCTAssertEqual(input.uuSafeUInt8(at: index), 0)
                XCTAssertEqual(input.uuSafeUInt8(at: index, defaultValue: 42), valid ? 0 : 42)

                for order in [UUByteOrder.littleEndian, .bigEndian]
                {
                    let generic: UInt8? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                }
            }
        }
        XCTAssertEqual(Data([255]).uuSafeUInt8(at: 0, defaultValue: 42), UInt8.max)
    }

    func test_uuUInt16_boundariesAndSafeDefaults()
    {
        let width = MemoryLayout<UInt16>.size
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data(repeating: 0, count: width - 1), Data(repeating: 0, count: width)]
            {
                for index in [-1, 0, input.count, input.count + 1]
                {
                    let valid = index == 0 && input.count == width
                    let expected: UInt16? = valid ? 0 : nil
                    XCTAssertEqual(input.uuUInt16(order: order, at: index), expected, "index: \(index), count: \(input.count)")
                    let generic: UInt16? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                    XCTAssertEqual(input.uuSafeUInt16(order: order, at: index), 0)
                    XCTAssertEqual(input.uuSafeUInt16(order: order, at: index, defaultValue: 42), valid ? 0 : 42)
                }
            }
            let input = Data(repeating: 255, count: width)
            XCTAssertEqual(input.uuSafeUInt16(order: order, at: 0, defaultValue: 42), UInt16.max)
        }
    }

    func test_uuUInt32_boundariesAndSafeDefaults()
    {
        let width = MemoryLayout<UInt32>.size
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data(repeating: 0, count: width - 1), Data(repeating: 0, count: width)]
            {
                for index in [-1, 0, input.count, input.count + 1]
                {
                    let valid = index == 0 && input.count == width
                    let expected: UInt32? = valid ? 0 : nil
                    XCTAssertEqual(input.uuUInt32(order: order, at: index), expected, "index: \(index), count: \(input.count)")
                    let generic: UInt32? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                    XCTAssertEqual(input.uuSafeUInt32(order: order, at: index), 0)
                    XCTAssertEqual(input.uuSafeUInt32(order: order, at: index, defaultValue: 42), valid ? 0 : 42)
                }
            }
            let input = Data(repeating: 255, count: width)
            XCTAssertEqual(input.uuSafeUInt32(order: order, at: 0, defaultValue: 42), UInt32.max)
        }
    }

    func test_uuUInt64_boundariesAndSafeDefaults()
    {
        let width = MemoryLayout<UInt64>.size
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data(repeating: 0, count: width - 1), Data(repeating: 0, count: width)]
            {
                for index in [-1, 0, input.count, input.count + 1]
                {
                    let valid = index == 0 && input.count == width
                    let expected: UInt64? = valid ? 0 : nil
                    XCTAssertEqual(input.uuUInt64(order: order, at: index), expected, "index: \(index), count: \(input.count)")
                    let generic: UInt64? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                    XCTAssertEqual(input.uuSafeUInt64(order: order, at: index), 0)
                    XCTAssertEqual(input.uuSafeUInt64(order: order, at: index, defaultValue: 42), valid ? 0 : 42)
                }
            }
            let input = Data(repeating: 255, count: width)
            XCTAssertEqual(input.uuSafeUInt64(order: order, at: 0, defaultValue: 42), UInt64.max)
        }
    }

    func test_uuInt8_boundariesAndSafeDefaults()
    {
        for input in [Data(), Data([0])]
        {
            for index in [-1, 0, input.count, input.count + 1]
            {
                let valid = index == 0 && !input.isEmpty
                let expected: Int8? = valid ? 0 : nil
                XCTAssertEqual(input.uuInt8(at: index), expected, "index: \(index), count: \(input.count)")
                XCTAssertEqual(input.uuSafeInt8(at: index), 0)
                XCTAssertEqual(input.uuSafeInt8(at: index, defaultValue: 42), valid ? 0 : 42)

                for order in [UUByteOrder.littleEndian, .bigEndian]
                {
                    let generic: Int8? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                }
            }
        }
        XCTAssertEqual(Data([255]).uuSafeInt8(at: 0, defaultValue: 42), -1)
    }

    func test_uuInt16_boundariesAndSafeDefaults()
    {
        let width = MemoryLayout<Int16>.size
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data(repeating: 0, count: width - 1), Data(repeating: 0, count: width)]
            {
                for index in [-1, 0, input.count, input.count + 1]
                {
                    let valid = index == 0 && input.count == width
                    let expected: Int16? = valid ? 0 : nil
                    XCTAssertEqual(input.uuInt16(order: order, at: index), expected, "index: \(index), count: \(input.count)")
                    let generic: Int16? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                    XCTAssertEqual(input.uuSafeInt16(order: order, at: index), 0)
                    XCTAssertEqual(input.uuSafeInt16(order: order, at: index, defaultValue: 42), valid ? 0 : 42)
                }
            }
            let input = Data(repeating: 255, count: width)
            XCTAssertEqual(input.uuSafeInt16(order: order, at: 0, defaultValue: 42), -1)
        }
    }

    func test_uuInt32_boundariesAndSafeDefaults()
    {
        let width = MemoryLayout<Int32>.size
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data(repeating: 0, count: width - 1), Data(repeating: 0, count: width)]
            {
                for index in [-1, 0, input.count, input.count + 1]
                {
                    let valid = index == 0 && input.count == width
                    let expected: Int32? = valid ? 0 : nil
                    XCTAssertEqual(input.uuInt32(order: order, at: index), expected, "index: \(index), count: \(input.count)")
                    let generic: Int32? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                    XCTAssertEqual(input.uuSafeInt32(order: order, at: index), 0)
                    XCTAssertEqual(input.uuSafeInt32(order: order, at: index, defaultValue: 42), valid ? 0 : 42)
                }
            }
            let input = Data(repeating: 255, count: width)
            XCTAssertEqual(input.uuSafeInt32(order: order, at: 0, defaultValue: 42), -1)
        }
    }

    func test_uuInt64_boundariesAndSafeDefaults()
    {
        let width = MemoryLayout<Int64>.size
        for order in [UUByteOrder.littleEndian, .bigEndian]
        {
            for input in [Data(), Data(repeating: 0, count: width - 1), Data(repeating: 0, count: width)]
            {
                for index in [-1, 0, input.count, input.count + 1]
                {
                    let valid = index == 0 && input.count == width
                    let expected: Int64? = valid ? 0 : nil
                    XCTAssertEqual(input.uuInt64(order: order, at: index), expected, "index: \(index), count: \(input.count)")
                    let generic: Int64? = input.uuInteger(order: order, at: index)
                    XCTAssertEqual(generic, expected)
                    XCTAssertEqual(input.uuSafeInt64(order: order, at: index), 0)
                    XCTAssertEqual(input.uuSafeInt64(order: order, at: index, defaultValue: 42), valid ? 0 : 42)
                }
            }
            let input = Data(repeating: 255, count: width)
            XCTAssertEqual(input.uuSafeInt64(order: order, at: 0, defaultValue: 42), -1)
        }
    }

    func test_uuString_encodingsAndFailures()
    {
        let input = Data([0x41, 0xC3, 0xA9, 0x42])
        XCTAssertEqual(input.uuString(at: 1, count: 2, with: .utf8), "é")
        XCTAssertEqual(input.uuString(at: 3, count: 99, with: .utf8), "B")
        XCTAssertNil(input.uuString(at: 1, count: 1, with: .utf8))
        XCTAssertNil(Data([0xFF]).uuString(at: 0, count: 1, with: .utf8))
        XCTAssertEqual(Data([0x41, 0, 0x42, 0]).uuString(at: 0, count: 4, with: .utf16LittleEndian), "AB")
        XCTAssertEqual(Data().uuString(at: 0, count: 0, with: .utf8), "")
        XCTAssertEqual(input.uuString(at: input.count, count: 1, with: .utf8), "")
        for (index, count) in [(-1, 1), (5, 1), (0, -1)]
        {
            XCTAssertNil(input.uuString(at: index, count: count, with: .utf8))
            XCTAssertEqual(input.uuSafeString(at: index, count: count, with: .utf8), "")
            XCTAssertEqual(input.uuSafeString(at: index, count: count, with: .utf8, defaultValue: "fallback"), "fallback")
        }
        XCTAssertEqual(input.uuSafeString(at: 1, count: 1, with: .utf8, defaultValue: "fallback"), "fallback")
        XCTAssertEqual(input.uuSafeString(at: 1, count: 2, with: .utf8, defaultValue: "fallback"), "é")
        XCTAssertEqual(input.uuSafeString(at: 0, count: 0, with: .utf8, defaultValue: "fallback"), "")
    }

    func test_uuAppendString_optionalAndUnicode()
    {
        do_uuAppendString_test(Data([0xAA]), data: "é😀", encoding: .utf8,
                              expected: [0xAA, 0xC3, 0xA9, 0xF0, 0x9F, 0x98, 0x80])
        do_uuAppendString_test(Data([0xAA]), data: "AB", encoding: .utf16BigEndian,
                              expected: [0xAA, 0, 0x41, 0, 0x42])
        var input = Data([1, 2])
        input.uuAppend(nil as String?)
        input.uuAppend("")
        input.uuAppend("é", encoding: .ascii)
        XCTAssertEqual(input, Data([1, 2]))
        input.uuAppend("A")
        XCTAssertEqual(input, Data([1, 2, 0x41]))
    }

    func test_uuAppendInteger_preservesExistingBytes()
    {
        do_uuAppendInteger_test(Data([0xAA]), data: UInt16(0x1234).bigEndian, expected: [0xAA, 0x12, 0x34])
        do_uuAppendInteger_test(Data([0xAA]), data: Int16(-129).littleEndian, expected: [0xAA, 0x7F, 0xFF])
    }

    func test_uuReplaceInteger_edgesAndSignedValues()
    {
        do_uuReplaceInteger_test([1, 2, 3, 4], data: Int16(-129).bigEndian, index: 0, expected: [0xFF, 0x7F, 3, 4])
        do_uuReplaceInteger_test([1, 2, 3, 4], data: Int16.min.littleEndian, index: 2, expected: [1, 2, 0, 0x80])
        do_uuReplaceInteger_test([1], data: Int8(-1), index: 0, expected: [0xFF])
        do_uuReplaceInteger_test([1, 2, 3, 4], data: Int32.min.bigEndian, index: 0, expected: [0x80, 0, 0, 0])
        do_uuReplaceInteger_test(Array(repeating: 0, count: 8), data: Int64(-1), index: 0, expected: Array(repeating: 255, count: 8))
    }

    func test_uuNibbles_offsetsAndInvalidIndices()
    {
        let input = Data([0, 0xAB])
        XCTAssertEqual(input.uuHighNibble(at: 1), 10)
        XCTAssertEqual(input.uuLowNibble(at: 1), 11)
        for index in [-1, 2, 3]
        {
            XCTAssertNil(input.uuHighNibble(at: index))
            XCTAssertNil(input.uuLowNibble(at: index))
        }
        XCTAssertNil(Data().uuHighNibble(at: 0))
        XCTAssertNil(Data().uuLowNibble(at: 0))
    }

    func test_uuBCD8_offsetsAndInvalidDigits()
    {
        let valid = Data([0xFF] + Array(repeating: UInt8(0x12), count: 1))
        XCTAssertEqual(valid.uuBCD8(at: 1), 12)
        for count in 0..<1
        {
            XCTAssertNil(Data(repeating: 0x12, count: count).uuBCD8(at: 0))
        }
        for index in [-1, valid.count, valid.count + 1]
        {
            XCTAssertNil(valid.uuBCD8(at: index))
        }
        for position in 0..<1
        {
            for invalid: UInt8 in [0xA0, 0x0A]
            {
                var input = Data(repeating: 0x12, count: 1)
                input[position] = invalid
                XCTAssertNil(input.uuBCD8(at: 0), "invalid byte at \(position)")
            }
        }
    }

    func test_uuBCD16_offsetsAndInvalidDigits()
    {
        let valid = Data([0xFF] + Array(repeating: UInt8(0x12), count: 2))
        XCTAssertEqual(valid.uuBCD16(at: 1), 1212)
        for count in 0..<2
        {
            XCTAssertNil(Data(repeating: 0x12, count: count).uuBCD16(at: 0))
        }
        for index in [-1, valid.count, valid.count + 1]
        {
            XCTAssertNil(valid.uuBCD16(at: index))
        }
        for position in 0..<2
        {
            for invalid: UInt8 in [0xA0, 0x0A]
            {
                var input = Data(repeating: 0x12, count: 2)
                input[position] = invalid
                XCTAssertNil(input.uuBCD16(at: 0), "invalid byte at \(position)")
            }
        }
    }

    func test_uuBCD24_offsetsAndInvalidDigits()
    {
        let valid = Data([0xFF] + Array(repeating: UInt8(0x12), count: 3))
        XCTAssertEqual(valid.uuBCD24(at: 1), 121212)
        for count in 0..<3
        {
            XCTAssertNil(Data(repeating: 0x12, count: count).uuBCD24(at: 0))
        }
        for index in [-1, valid.count, valid.count + 1]
        {
            XCTAssertNil(valid.uuBCD24(at: index))
        }
        for position in 0..<3
        {
            for invalid: UInt8 in [0xA0, 0x0A]
            {
                var input = Data(repeating: 0x12, count: 3)
                input[position] = invalid
                XCTAssertNil(input.uuBCD24(at: 0), "invalid byte at \(position)")
            }
        }
    }

    func test_uuBCD32_offsetsAndInvalidDigits()
    {
        let valid = Data([0xFF] + Array(repeating: UInt8(0x12), count: 4))
        XCTAssertEqual(valid.uuBCD32(at: 1), 12121212)
        for count in 0..<4
        {
            XCTAssertNil(Data(repeating: 0x12, count: count).uuBCD32(at: 0))
        }
        for index in [-1, valid.count, valid.count + 1]
        {
            XCTAssertNil(valid.uuBCD32(at: index))
        }
        for position in 0..<4
        {
            for invalid: UInt8 in [0xA0, 0x0A]
            {
                var input = Data(repeating: 0x12, count: 4)
                input[position] = invalid
                XCTAssertNil(input.uuBCD32(at: 0), "invalid byte at \(position)")
            }
        }
    }

    func test_uuSlice_emptyAndSingleByteChunks()
    {
        XCTAssertEqual(Data().uuSlice(chunkSize: 2), [])
        XCTAssertEqual(Data([1, 2, 3]).uuSlice(chunkSize: 1), [Data([1]), Data([2]), Data([3])])
        XCTAssertEqual(Data([1, 2]).uuSlice(chunkSize: 2), [Data([1, 2])])
    }

    func test_uuSlice_zeroChunkSize() throws
    {
        XCTAssertEqual(Data([1]).uuSlice(chunkSize: 0), [])
    }

    func test_uuSlice_negativeChunkSize() throws
    {
        XCTAssertEqual(Data([1]).uuSlice(chunkSize: -1), [])
    }

    func test_uuPadded_emptyZeroAndMultipleBlocks()
    {
        XCTAssertEqual(Data().uuPadded(toLength: 0), Data())
        XCTAssertEqual(Data().uuPadded(toLength: 3), Data([0, 0, 0]))
        XCTAssertEqual(Data([1, 2]).uuPadded(toLength: 0), Data())
        XCTAssertEqual(Data().uuPadded(toBlockSize: 4), Data())
        XCTAssertEqual(Data([1, 2]).uuPadded(toBlockSize: 1), Data([1, 2]))
        let input = Data([1, 2, 3, 4, 5])
        XCTAssertEqual(input.uuPadded(toBlockSize: 4), Data([1, 2, 3, 4, 5, 0, 0, 0]))
        XCTAssertEqual(Data([1, 2, 3, 4]).uuPadded(toBlockSize: 2), Data([1, 2, 3, 4]))
        XCTAssertEqual(input, Data([1, 2, 3, 4, 5]))
        // Nonpositive block sizes violate the documented precondition; no return value is asserted.
    }

    func test_uuXor_emptySelfAndPreservesInputs()
    {
        XCTAssertEqual(Data().uuXor(with: Data()), Data())
        XCTAssertEqual(Data().uuXor(with: Data([1])), Data())
        let input = Data([0x12, 0xAB])
        let other = Data([0xFF, 0xFF])
        XCTAssertEqual(input.uuXor(with: input), Data([0, 0]))
        XCTAssertEqual(input.uuXor(with: other), Data([0xED, 0x54]))
        XCTAssertEqual(input, Data([0x12, 0xAB]))
        XCTAssertEqual(other, Data([0xFF, 0xFF]))
    }

    func test_uuResetAndSetAll_emptyAndCopySemantics()
    {
        var empty = Data()
        empty.uuReset()
        empty.uuSetAll(to: 255)
        XCTAssertEqual(empty, Data())
        let original = Data([1, 2, 3])
        var copy = original
        copy.uuSetAll(to: 255)
        XCTAssertEqual(copy, Data([255, 255, 255]))
        copy.uuReset()
        XCTAssertEqual(copy, Data([0, 0, 0]))
        XCTAssertEqual(original, Data([1, 2, 3]))
    }

    func test_uuReversed_emptySingleAndMultiple()
    {
        for bytes: [UInt8] in [[], [1], [1, 2, 3, 4]]
        {
            let input = Data(bytes)
            XCTAssertEqual(input.uuReversed(), Data(bytes.reversed()))
            XCTAssertEqual(input.uuReversed().uuReversed(), input)
            XCTAssertEqual(input, Data(bytes))
        }
    }

    func test_uuToJson_objectsArraysAndInvalidInput() throws
    {
        let object = try XCTUnwrap(Data(#"{"name":"é","count":2}"#.utf8).uuToJson() as? [String: Any])
        XCTAssertEqual(object["name"] as? String, "é")
        XCTAssertEqual(object["count"] as? Int, 2)
        XCTAssertEqual(Data("[1,2,3]".utf8).uuToJson() as? [Int], [1, 2, 3])
        XCTAssertEqual(Data("[]".utf8).uuToJson() as? [Int], [])
        for input in [Data(), Data("{invalid}".utf8), Data([0xFF]), Data("42".utf8)]
        {
            XCTAssertNil(input.uuToJson())
        }
    }

    func test_uuToJsonString_producesParseableJSON() throws
    {
        // Contract follows the API comment: output must be JSON, not a Foundation object description.
        for source in [#"{"name":"é","count":2}"#, "[1,2,3]", "{}", "[]"]
        {
            let input = Data(source.utf8)
            let output = input.uuToJsonString()
            let expected = try JSONSerialization.jsonObject(with: input) as! NSObject
            let actual = try JSONSerialization.jsonObject(with: Data(output.utf8)) as! NSObject
            XCTAssertEqual(actual, expected)
        }
    }

    func test_uuToJsonString_invalidInput()
    {
        XCTAssertEqual(Data().uuToJsonString(), "")
        XCTAssertEqual(Data("invalid".utf8).uuToJsonString(), "")
    }

    func test_uuSlicedData_valueOperations()
    {
        let input = Data([0xFF, 0x12, 0x34, 0x56]).dropFirst()
        XCTAssertEqual(input.startIndex, 1)
        XCTAssertEqual(input.uuBytes, [0x12, 0x34, 0x56])
        XCTAssertEqual(input.uuReversed(), Data([0x56, 0x34, 0x12]))
        XCTAssertEqual(input.uuToBinaryString(), "00010010 00110100 01010110")
        XCTAssertEqual(input.uuPadded(toLength: 2), Data([0x12, 0x34]))
        XCTAssertEqual(input.uuPadded(toLength: 4), Data([0x12, 0x34, 0x56, 0]))
        XCTAssertEqual(input.uuPadded(toBlockSize: 2), Data([0x12, 0x34, 0x56, 0]))
        XCTAssertEqual(input.uuSha256(), Data([0x12, 0x34, 0x56]).uuSha256())
        XCTAssertEqual(input.uuSha384(), Data([0x12, 0x34, 0x56]).uuSha384())
        XCTAssertEqual(input.uuSha512(), Data([0x12, 0x34, 0x56]).uuSha512())
    }

    func test_uuSlicedData_hexString() throws
    {
        XCTAssertEqual(Data([0, 0x12, 0x34]).dropFirst().uuToHexString(), "1234")
    }

    func test_uuSlicedData_relativeOffsets() throws
    {
        let input = Data([0, 0x12, 0x34, 0x56]).dropFirst()
        XCTAssertEqual(input.uuData(at: 0, count: 2), Data([0x12, 0x34]))
        XCTAssertEqual(input.uuUInt16(order: .bigEndian, at: 0), 0x1234)
        XCTAssertEqual(input.uuSlice(chunkSize: 2), [Data([0x12, 0x34]), Data([0x56])])
    }

    func test_uuSlicedData_reset() throws
    {
        var input = Data([9, 1, 2, 3]).dropFirst()
        input.uuReset()
        XCTAssertEqual(input, Data([0, 0, 0]))
    }

    func test_uuSlicedData_setAll() throws
    {
        var input = Data([9, 1, 2, 3]).dropFirst()
        input.uuSetAll(to: 255)
        XCTAssertEqual(input, Data([255, 255, 255]))
    }

    func test_uuSlicedData_xorWithDifferentStartIndices() throws
    {
        let input = Data([9, 0x12, 0x34]).dropFirst()
        XCTAssertEqual(input.uuXor(with: Data([0xFF, 0xFF])), Data([0xED, 0xCB]))
    }

    func test_uuSafeUInt16_byteOrderAtNonzeroOffset()
    {
        let input = Data([0xAA, 1] + Array(repeating: UInt8(0), count: 1))
        XCTAssertEqual(input.uuSafeUInt16(order: .littleEndian, at: 1, defaultValue: 42), 1)
        XCTAssertEqual(input.uuSafeUInt16(order: .bigEndian, at: 1, defaultValue: 42), UInt16(1) << 8)
    }

    func test_uuSafeUInt32_byteOrderAtNonzeroOffset()
    {
        let input = Data([0xAA, 1] + Array(repeating: UInt8(0), count: 3))
        XCTAssertEqual(input.uuSafeUInt32(order: .littleEndian, at: 1, defaultValue: 42), 1)
        XCTAssertEqual(input.uuSafeUInt32(order: .bigEndian, at: 1, defaultValue: 42), UInt32(1) << 24)
    }

    func test_uuSafeUInt64_byteOrderAtNonzeroOffset()
    {
        let input = Data([0xAA, 1] + Array(repeating: UInt8(0), count: 7))
        XCTAssertEqual(input.uuSafeUInt64(order: .littleEndian, at: 1, defaultValue: 42), 1)
        XCTAssertEqual(input.uuSafeUInt64(order: .bigEndian, at: 1, defaultValue: 42), UInt64(1) << 56)
    }

    func test_uuSafeInt16_byteOrderAtNonzeroOffset()
    {
        let input = Data([0xAA, 1] + Array(repeating: UInt8(0), count: 1))
        XCTAssertEqual(input.uuSafeInt16(order: .littleEndian, at: 1, defaultValue: 42), 1)
        XCTAssertEqual(input.uuSafeInt16(order: .bigEndian, at: 1, defaultValue: 42), Int16(1) << 8)
    }

    func test_uuSafeInt32_byteOrderAtNonzeroOffset()
    {
        let input = Data([0xAA, 1] + Array(repeating: UInt8(0), count: 3))
        XCTAssertEqual(input.uuSafeInt32(order: .littleEndian, at: 1, defaultValue: 42), 1)
        XCTAssertEqual(input.uuSafeInt32(order: .bigEndian, at: 1, defaultValue: 42), Int32(1) << 24)
    }

    func test_uuSafeInt64_byteOrderAtNonzeroOffset()
    {
        let input = Data([0xAA, 1] + Array(repeating: UInt8(0), count: 7))
        XCTAssertEqual(input.uuSafeInt64(order: .littleEndian, at: 1, defaultValue: 42), 1)
        XCTAssertEqual(input.uuSafeInt64(order: .bigEndian, at: 1, defaultValue: 42), Int64(1) << 56)
    }

    func test_uuInt16_bigEndianSignedLimits()
    {
        XCTAssertEqual(Data([0x80] + Array(repeating: UInt8(0), count: 1)).uuInt16(order: .bigEndian, at: 0), Int16.min)
        XCTAssertEqual(Data([0x7F] + Array(repeating: UInt8(255), count: 1)).uuInt16(order: .bigEndian, at: 0), Int16.max)
    }

    func test_uuInt32_bigEndianSignedLimits()
    {
        XCTAssertEqual(Data([0x80] + Array(repeating: UInt8(0), count: 3)).uuInt32(order: .bigEndian, at: 0), Int32.min)
        XCTAssertEqual(Data([0x7F] + Array(repeating: UInt8(255), count: 3)).uuInt32(order: .bigEndian, at: 0), Int32.max)
    }

    func test_uuInt64_bigEndianSignedLimits()
    {
        XCTAssertEqual(Data([0x80] + Array(repeating: UInt8(0), count: 7)).uuInt64(order: .bigEndian, at: 0), Int64.min)
        XCTAssertEqual(Data([0x7F] + Array(repeating: UInt8(255), count: 7)).uuInt64(order: .bigEndian, at: 0), Int64.max)
    }
    func test_uuSlice_extremeChunkSize()
    {
        XCTAssertEqual(Data([1, 2, 3]).uuSlice(chunkSize: Int.max), [Data([1, 2, 3])])
        XCTAssertEqual(Data([1]).uuSlice(chunkSize: Int.min), [])
    }

    func test_uuSlicedData_replaceUsesRelativeOffset()
    {
        let original = Data([9, 1, 2, 3, 4])
        var input = original.dropFirst()
        input.uuReplace(UInt16(0xABCD).bigEndian, at: 2)
        XCTAssertEqual(input, Data([1, 2, 0xAB, 0xCD]))
        XCTAssertEqual(original, Data([9, 1, 2, 3, 4]))
    }
    func test_uuEightBitReaders_allByteValuesAndSlices()
    {
        let bytes = (0...255).map { UInt8($0) }
        let sliced = Data([0xAA] + bytes).dropFirst()
        XCTAssertEqual(sliced.startIndex, 1)

        for input in [Data(bytes), sliced]
        {
            for offset in 0...255
            {
                let unsigned = UInt8(offset)
                let signed = Int8(offset < 128 ? offset : offset - 256)
                XCTAssertEqual(input.uuUInt8(at: offset), unsigned)
                XCTAssertEqual(input.uuInt8(at: offset), signed)
                XCTAssertEqual(input.uuSafeUInt8(at: offset, defaultValue: 42), unsigned)
                XCTAssertEqual(input.uuSafeInt8(at: offset, defaultValue: 42), signed)
            }
            for offset in [Int.min, -1, input.count, Int.max]
            {
                XCTAssertNil(input.uuUInt8(at: offset))
                XCTAssertNil(input.uuInt8(at: offset))
                XCTAssertEqual(input.uuSafeUInt8(at: offset, defaultValue: 42), 42)
                XCTAssertEqual(input.uuSafeInt8(at: offset, defaultValue: -42), -42)
            }
        }
    }
}
