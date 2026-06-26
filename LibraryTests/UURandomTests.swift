//
//  UURandomTests.swift
//  UUSwiftCoreTests
//
//  Created by Ryan DeVore on 6/26/26.
//

import XCTest
@testable import UUSwiftCore

private enum UURandomTestSupport
{
    static let loops = 20

    static func randomCount() -> Int
    {
        return UURandom.int(min: 1, max: 22)
    }
}

final class UURandomBytesTests: XCTestCase
{
    func test_bytes_returnsRequestedLength()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let length = UURandomTestSupport.randomCount()
            XCTAssertEqual(UURandom.bytes(length: length).count, length)
        }
    }

    func test_bytes_negativeLength_returnsEmptyData()
    {
        XCTAssertEqual(UURandom.bytes(length: -1), Data())
    }

    func test_bytes_zeroLength_returnsEmptyData()
    {
        XCTAssertEqual(UURandom.bytes(length: 0), Data())
    }

    func test_bytesOrNull_returnsRequestedLengthWhenNonNil()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let length = UURandomTestSupport.randomCount()
            guard let actual = UURandom.bytesOrNull(length: length) else
            {
                continue
            }

            XCTAssertEqual(actual.count, length)
        }
    }
}

final class UURandomScalarTests: XCTestCase
{
    func test_byte_isSignedByteRange()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = Int(UURandom.byte())
            XCTAssertGreaterThanOrEqual(actual, Int(Int8.min))
            XCTAssertLessThanOrEqual(actual, Int(Int8.max))
        }
    }

    func test_uByte_isUnsignedByteRange()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.uByte()
            XCTAssertGreaterThanOrEqual(actual, UInt8.min)
            XCTAssertLessThanOrEqual(actual, UInt8.max)
        }
    }

    func test_short_isSignedShortRange()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = Int(UURandom.short())
            XCTAssertGreaterThanOrEqual(actual, Int(Int16.min))
            XCTAssertLessThanOrEqual(actual, Int(Int16.max))
        }
    }

    func test_uShort_isUnsignedShortRange()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.uShort()
            XCTAssertGreaterThanOrEqual(actual, UInt16.min)
            XCTAssertLessThanOrEqual(actual, UInt16.max)
        }
    }

    func test_int_isSignedInt32Range()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.int()
            XCTAssertGreaterThanOrEqual(actual, Int(Int32.min))
            XCTAssertLessThanOrEqual(actual, Int(Int32.max))
        }
    }

    func test_uInt_isUnsignedInt32Range()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.uInt()
            XCTAssertGreaterThanOrEqual(actual, UInt(UInt32.min))
            XCTAssertLessThanOrEqual(actual, UInt(UInt32.max))
        }
    }

    func test_long_returnsValue()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            _ = UURandom.long()
        }
    }

    func test_uLong_returnsValue()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            _ = UURandom.uLong()
        }
    }

    func test_float_isUnitInterval()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.float()
            XCTAssertGreaterThanOrEqual(actual, 0)
            XCTAssertLessThan(actual, 1)
        }
    }

    func test_double_isUnitInterval()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.double()
            XCTAssertGreaterThanOrEqual(actual, 0)
            XCTAssertLessThan(actual, 1)
        }
    }

    func test_bool_returnsBool()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            _ = UURandom.bool()
        }
    }

    func test_char_isValidUnicodeScalar()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.char()
            XCTAssertFalse(String(actual).isEmpty)
        }
    }

    func test_uuid_parsesAsUUID()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            XCTAssertNotNil(UUID(uuidString: UURandom.uuid()))
        }
    }
}

final class UURandomIntRangeTests: XCTestCase
{
    func test_int_minMax_positiveRange()
    {
        let min = 0
        let max = 1000

        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.int(min: min, max: max)
            XCTAssertGreaterThanOrEqual(actual, min)
            XCTAssertLessThan(actual, max)
        }
    }

    func test_int_minMax_negativeRange()
    {
        let min = -1000
        let max = 1000

        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.int(min: min, max: max)
            XCTAssertGreaterThanOrEqual(actual, min)
            XCTAssertLessThan(actual, max)
        }
    }

    func test_int_max_upperBound()
    {
        let max = 1000

        for _ in 0..<UURandomTestSupport.loops
        {
            let actual = UURandom.int(max: max)
            XCTAssertGreaterThanOrEqual(actual, 0)
            XCTAssertLessThan(actual, max)
        }
    }
}

final class UURandomArrayTests: XCTestCase
{
    func test_objArray_respectsMaxLength()
    {
        struct TestObj
        {
            let a: Int
            let b: Int
        }

        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            let actual = UURandom.objArray(maxLength: maxLength)
            {
                TestObj(a: UURandom.int(), b: UURandom.int())
            }

            XCTAssertLessThanOrEqual(actual.count, maxLength)
        }
    }

    func test_byteObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.byteObjArray(maxLength:))
    }

    func test_uByteObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.uByteObjArray(maxLength:))
    }

    func test_shortObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.shortObjArray(maxLength:))
    }

    func test_uShortObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.uShortObjArray(maxLength:))
    }

    func test_intObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.intObjArray(maxLength:))
    }

    func test_uIntObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.uIntObjArray(maxLength:))
    }

    func test_longObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.longObjArray(maxLength:))
    }

    func test_uLongObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.uLongObjArray(maxLength:))
    }

    func test_floatObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.floatObjArray(maxLength:))
    }

    func test_doubleObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.doubleObjArray(maxLength:))
    }

    func test_boolObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.boolObjArray(maxLength:))
    }

    func test_charObjArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.charObjArray(maxLength:))
    }

    func test_shortArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.shortArray(maxLength:))
    }

    func test_intArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.intArray(maxLength:))
    }

    func test_longArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.longArray(maxLength:))
    }

    func test_floatArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.floatArray(maxLength:))
    }

    func test_doubleArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.doubleArray(maxLength:))
    }

    func test_boolArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.boolArray(maxLength:))
    }

    func test_charArray_respectsMaxLength()
    {
        assertArrayRespectsMaxLength(UURandom.charArray(maxLength:))
    }

    private func assertArrayRespectsMaxLength<T>(_ makeArray: (Int) -> [T])
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            XCTAssertLessThanOrEqual(makeArray(maxLength).count, maxLength)
        }
    }
}

final class UURandomStringTests: XCTestCase
{
    func test_asciiLetters_containsOnlyLetters()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            let actual = UURandom.asciiLetters(maxLength: maxLength)
            XCTAssertLessThanOrEqual(actual.count, maxLength)
            XCTAssertTrue(actual.allSatisfy(isAsciiLetter))
        }
    }

    func test_digits_containsOnlyDigits()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            let actual = UURandom.digits(maxLength: maxLength)
            XCTAssertLessThanOrEqual(actual.count, maxLength)
            XCTAssertTrue(actual.allSatisfy(isAsciiDigit))
        }
    }

    func test_asciiLettersOrNumbers_containsOnlyLettersOrDigits()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            let actual = UURandom.asciiLettersOrNumbers(maxLength: maxLength)
            XCTAssertLessThanOrEqual(actual.count, maxLength)
            XCTAssertTrue(actual.allSatisfy { isAsciiLetter($0) || isAsciiDigit($0) })
        }
    }

    func test_chars_respectsProvidedRanges()
    {
        let ranges: [(Character, Character)] = [("A", "Z"), ("a", "z")]

        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            let actual = UURandom.chars(maxLength: maxLength, ranges: ranges)
            XCTAssertLessThanOrEqual(actual.count, maxLength)
            XCTAssertTrue(actual.allSatisfy(isAsciiLetter))
        }
    }

    func test_asciiWord_containsOnlyLetters()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let maxLength = UURandomTestSupport.randomCount()
            let actual = UURandom.asciiWord(maxLength: maxLength)
            XCTAssertLessThanOrEqual(actual.count, maxLength)
            XCTAssertTrue(actual.allSatisfy(isAsciiLetter))
        }
    }

    func test_asciiWords_wordsAreLettersAndWithinBounds()
    {
        for _ in 0..<UURandomTestSupport.loops
        {
            let maxWords = UURandomTestSupport.randomCount()
            let maxWordLength = UURandomTestSupport.randomCount()
            let actual = UURandom.asciiWords(maxNumberOfWords: maxWords, maxWordLength: maxWordLength)
            let words = actual.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
            XCTAssertLessThanOrEqual(words.count, maxWords)

            for word in words where !word.isEmpty
            {
                XCTAssertLessThanOrEqual(word.count, maxWordLength)
                XCTAssertTrue(word.allSatisfy(isAsciiLetter))
            }
        }
    }

    private func isAsciiLetter(_ character: Character) -> Bool
    {
        return ("A"..."Z").contains(character) || ("a"..."z").contains(character)
    }

    private func isAsciiDigit(_ character: Character) -> Bool
    {
        return ("0"..."9").contains(character)
    }
}

final class UURandomOrNullTests: XCTestCase
{
    func test_orNullVariants_canReturnNil()
    {
        XCTAssertTrue(collectNilResults { UURandom.bytesOrNull(length: 8) })
        XCTAssertTrue(collectNilResults { UURandom.byteOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.uByteOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.shortOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.uShortOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.intOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.intOrNull(max: 1000) })
        XCTAssertTrue(collectNilResults { UURandom.intOrNull(min: -1000, max: 1000) })
        XCTAssertTrue(collectNilResults { UURandom.uIntOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.longOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.uLongOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.floatOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.doubleOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.boolOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.charOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.uuidOrNull() })
        XCTAssertTrue(collectNilResults { UURandom.byteObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.uByteObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.shortObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.uShortObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.intObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.uIntObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.longObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.uLongObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.floatObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.doubleObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.boolObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.charObjArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.shortArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.intArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.longArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.floatArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.doubleArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.boolArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.charArrayOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.asciiLettersOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.digitsOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.asciiLettersOrNumbersOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.charsOrNull(maxLength: 8, ranges: [("A", "Z")]) })
        XCTAssertTrue(collectNilResults { UURandom.asciiWordOrNull(maxLength: 8) })
        XCTAssertTrue(collectNilResults { UURandom.asciiWordsOrNull(maxNumberOfWords: 4, maxWordLength: 8) })
        XCTAssertTrue(collectNilResults
        {
            UURandom.objArrayOrNull(maxLength: 8)
            {
                UURandom.int()
            }
        })
    }

    private func collectNilResults<T>(_ makeValue: () -> T?) -> Bool
    {
        for _ in 0..<64
        {
            if makeValue() == nil
            {
                return true
            }
        }

        return false
    }
}

final class UURandomDistributionTests: XCTestCase
{
    func test_bytes_producesDistinctValues()
    {
        var samples = Set<Data>()

        for _ in 0..<UURandomTestSupport.loops
        {
            samples.insert(UURandom.bytes(length: 16))
        }

        XCTAssertGreaterThan(samples.count, 1)
    }
}
