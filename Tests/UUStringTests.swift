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
    // MARK: - uuFirstCapital

    func test_uuFirstCapital_empty()
    {
        XCTAssertEqual("".uuFirstCapital(), "")
    }

    func test_uuFirstCapital_singleCharacter()
    {
        XCTAssertEqual("a".uuFirstCapital(), "A")
        XCTAssertEqual("A".uuFirstCapital(), "A")
    }

    func test_uuFirstCapital_typicalWords()
    {
        XCTAssertEqual("hello".uuFirstCapital(), "Hello")
        XCTAssertEqual("HELLO".uuFirstCapital(), "Hello")
        XCTAssertEqual("hELLO".uuFirstCapital(), "Hello")
    }

    func test_uuFirstCapital_multipleWordsUnchangedExceptFirstChar()
    {
        XCTAssertEqual("hello world".uuFirstCapital(), "Hello world")
    }

    // MARK: - uuSnakeToCamelCase

    func test_uuSnakeToCamelCase_basic()
    {
        XCTAssertEqual("user_name".uuSnakeToCamelCase(), "userName")
        XCTAssertEqual("USER_NAME".uuSnakeToCamelCase(), "userName")
    }

    func test_uuSnakeToCamelCase_singleSegment()
    {
        XCTAssertEqual("user".uuSnakeToCamelCase(), "user")
        XCTAssertEqual("USER".uuSnakeToCamelCase(), "user")
    }

    func test_uuSnakeToCamelCase_empty()
    {
        XCTAssertEqual("".uuSnakeToCamelCase(), "")
    }

    func test_uuSnakeToCamelCase_consecutiveUnderscores()
    {
        XCTAssertEqual("user__name".uuSnakeToCamelCase(), "userName")
    }

    func test_uuSnakeToCamelCase_leadingUnderscores()
    {
        XCTAssertEqual("__user".uuSnakeToCamelCase(), "User")
    }

    func test_uuSnakeToCamelCase_trailingUnderscore()
    {
        XCTAssertEqual("user_".uuSnakeToCamelCase(), "user")
    }

    func test_uuSnakeToCamelCase_multipleSegments()
    {
        XCTAssertEqual("one_two_three".uuSnakeToCamelCase(), "oneTwoThree")
    }

    /// Table-driven cases aligned with Kotlin `test_uuSnakeToCamelCase`.
    func test_uuSnakeToCamelCase_table()
    {
        let cases: [(String, String)] = [
            ("", ""),
            ("user_name", "userName"),
            ("USER_NAME", "userName"),
            ("single", "single"),
            ("a_b_c", "abc"),
            ("aa_bb_cc", "aaBbCc"),
            ("user__name", "userName"),
        ]
        for (input, expected) in cases
        {
            NSLog("Input: \(input), Expected: \(expected)")
            XCTAssertEqual(input.uuSnakeToCamelCase(), expected, "input=\(input), expected=\(expected), actual=\(input.uuSnakeToCamelCase())")
        }
    }

    // MARK: - uuSnakeToPascalCase

    func test_uuSnakeToPascalCase_basic()
    {
        XCTAssertEqual("user_name".uuSnakeToPascalCase(), "UserName")
        XCTAssertEqual("USER_NAME".uuSnakeToPascalCase(), "UserName")
    }

    func test_uuSnakeToPascalCase_singleSegment()
    {
        XCTAssertEqual("user".uuSnakeToPascalCase(), "User")
        XCTAssertEqual("USER".uuSnakeToPascalCase(), "User")
    }

    func test_uuSnakeToPascalCase_empty()
    {
        XCTAssertEqual("".uuSnakeToPascalCase(), "")
    }

    func test_uuSnakeToPascalCase_consecutiveUnderscores()
    {
        XCTAssertEqual("user__name".uuSnakeToPascalCase(), "UserName")
    }

    func test_uuSnakeToPascalCase_leadingUnderscores()
    {
        XCTAssertEqual("__user".uuSnakeToPascalCase(), "User")
    }

    func test_uuSnakeToPascalCase_trailingUnderscore()
    {
        XCTAssertEqual("user_".uuSnakeToPascalCase(), "User")
    }

    func test_uuSnakeToPascalCase_multipleSegments()
    {
        XCTAssertEqual("one_two_three".uuSnakeToPascalCase(), "OneTwoThree")
    }

    /// Table-driven cases aligned with Kotlin `test_uuSnakeToPascalCase`.
    func test_uuSnakeToPascalCase_table()
    {
        let cases: [(String, String)] = [
            ("", ""),
            ("user_name", "UserName"),
            ("USER_NAME", "UserName"),
            ("single", "Single"),
            ("a_b_c", "ABC"),
            ("aa_bb_cc", "AaBbCc"),
            ("user__name", "UserName"),
        ]
        for (input, expected) in cases
        {
            XCTAssertEqual(input.uuSnakeToPascalCase(), expected, "input=\(input)")
        }
    }

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
