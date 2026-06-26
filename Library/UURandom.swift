//
//  UURandom.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/26/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Cryptographically secure random value generation for test data, samples, and app logic.
//

import Foundation
import Security

/// Helpers for generating cryptographically secure random values.
///
/// All byte generation uses ``SecRandomCopyBytes`` (`kSecRandomDefault`).
public struct UURandom
{
    private static let upperCase: (Character, Character) = ("A", "Z")
    private static let lowerCase: (Character, Character) = ("a", "z")
    private static let numbers: (Character, Character) = ("0", "9")

    private init()
    {
    }

    // MARK: - Bytes

    /// Generates a random byte buffer of the requested length.
    ///
    /// Returns empty data when `length` is negative or when secure random generation fails.
    public static func bytes(length: Int) -> Data
    {
        guard length > 0 else
        {
            return Data()
        }

        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes
        { buffer in
            guard let baseAddress = buffer.baseAddress else
            {
                return errSecParam
            }

            return SecRandomCopyBytes(kSecRandomDefault, length, baseAddress)
        }

        guard status == errSecSuccess else
        {
            return Data()
        }

        return data
    }

    /// Generates random bytes, or `nil` when ``bool()`` is `false`.
    public static func bytesOrNull(length: Int) -> Data?
    {
        return bool() ? bytes(length: length) : nil
    }

    // MARK: - Int

    /// Generates a random 32-bit signed integer.
    public static func int() -> Int
    {
        return Int(loadInteger(Int32.self))
    }

    /// Generates a random integer in `min...max` (both bounds inclusive).
    public static func int(min: Int, max: Int) -> Int
    {
        guard min <= max else
        {
            return min
        }

        if min == max
        {
            return min
        }

        let span = UInt64(max &- min) + 1
        return min &+ Int(truncatingIfNeeded: secureUniform(span: span))
    }

    /// Generates a random integer in `0...max` (inclusive).
    public static func int(max: Int) -> Int
    {
        return int(min: 0, max: max)
    }

    /// Generates a random 32-bit signed integer, or `nil` when ``bool()`` is `false`.
    public static func intOrNull() -> Int?
    {
        return bool() ? int() : nil
    }

    /// Generates a random integer in `min...max`, or `nil` when ``bool()`` is `false`.
    public static func intOrNull(min: Int, max: Int) -> Int?
    {
        return bool() ? int(min: min, max: max) : nil
    }

    /// Generates a random integer in `0...max`, or `nil` when ``bool()`` is `false`.
    public static func intOrNull(max: Int) -> Int?
    {
        return bool() ? int(max: max) : nil
    }

    // MARK: - UInt

    /// Generates a random 32-bit unsigned integer.
    public static func uInt() -> UInt
    {
        return UInt(loadInteger(UInt32.self))
    }

    /// Generates a random 32-bit unsigned integer, or `nil` when ``bool()`` is `false`.
    public static func uIntOrNull() -> UInt?
    {
        return bool() ? uInt() : nil
    }

    // MARK: - Int64

    /// Generates a random 64-bit signed integer.
    public static func long() -> Int64
    {
        return loadInteger(Int64.self)
    }

    /// Generates a random 64-bit signed integer, or `nil` when ``bool()`` is `false`.
    public static func longOrNull() -> Int64?
    {
        return bool() ? long() : nil
    }

    // MARK: - UInt64

    /// Generates a random 64-bit unsigned integer.
    public static func uLong() -> UInt64
    {
        return loadInteger(UInt64.self)
    }

    /// Generates a random 64-bit unsigned integer, or `nil` when ``bool()`` is `false`.
    public static func uLongOrNull() -> UInt64?
    {
        return bool() ? uLong() : nil
    }

    // MARK: - Floating point

    /// Generates a random `Double` in `0.0..<1.0`.
    public static func double() -> Double
    {
        let bits = loadInteger(UInt64.self) >> 11
        return Double(bits) * (1.0 / Double(1 << 53))
    }

    /// Generates a random `Double`, or `nil` when ``bool()`` is `false`.
    public static func doubleOrNull() -> Double?
    {
        return bool() ? double() : nil
    }

    /// Generates a random `Float` in `0.0..<1.0`.
    public static func float() -> Float
    {
        let bits = loadInteger(UInt32.self) >> 8
        return Float(bits) * (1.0 / Float(1 << 24))
    }

    /// Generates a random `Float`, or `nil` when ``bool()`` is `false`.
    public static func floatOrNull() -> Float?
    {
        return bool() ? float() : nil
    }

    // MARK: - Bool

    /// Generates a random `Bool`.
    public static func bool() -> Bool
    {
        return (loadInteger(UInt8.self) & 1) == 0
    }

    /// Generates a random `Bool`, or `nil` when ``bool()`` is `false`.
    public static func boolOrNull() -> Bool?
    {
        return bool() ? bool() : nil
    }

    // MARK: - Byte

    /// Generates a random signed byte.
    public static func byte() -> Int8
    {
        return Int8(bitPattern: loadInteger(UInt8.self))
    }

    /// Generates a random signed byte, or `nil` when ``bool()`` is `false`.
    public static func byteOrNull() -> Int8?
    {
        return bool() ? byte() : nil
    }

    /// Generates a random unsigned byte.
    public static func uByte() -> UInt8
    {
        return loadInteger(UInt8.self)
    }

    /// Generates a random unsigned byte, or `nil` when ``bool()`` is `false`.
    public static func uByteOrNull() -> UInt8?
    {
        return bool() ? uByte() : nil
    }

    // MARK: - Short

    /// Generates a random signed 16-bit integer from secure random bytes (big-endian).
    public static func short() -> Int16
    {
        return loadInteger(Int16.self)
    }

    /// Generates a random signed 16-bit integer, or `nil` when ``bool()`` is `false`.
    public static func shortOrNull() -> Int16?
    {
        return bool() ? short() : nil
    }

    /// Generates a random unsigned 16-bit integer.
    public static func uShort() -> UInt16
    {
        return UInt16(bitPattern: short())
    }

    /// Generates a random unsigned 16-bit integer, or `nil` when ``bool()`` is `false`.
    public static func uShortOrNull() -> UInt16?
    {
        return bool() ? uShort() : nil
    }

    // MARK: - Character

    /// Generates a random UTF-16 code unit as a `Character`.
    public static func char() -> Character
    {
        let codeUnit = uShort()
        return Character(String(utf16CodeUnits: [codeUnit], count: 1))
    }

    /// Generates a random `Character`, or `nil` when ``bool()`` is `false`.
    public static func charOrNull() -> Character?
    {
        return bool() ? char() : nil
    }

    // MARK: - UUID

    /// Generates a random UUID string.
    public static func uuid() -> String
    {
        return UUID().uuidString
    }

    /// Generates a random UUID string, or `nil` when ``bool()`` is `false`.
    public static func uuidOrNull() -> String?
    {
        return bool() ? uuid() : nil
    }

    // MARK: - Object arrays

    /// Generates an array of random elements with length in `0..<maxLength`.
    public static func objArray<T>(maxLength: Int, random: () -> T) -> [T]
    {
        let length = int(max: maxLength)
        var result = [T]()
        result.reserveCapacity(length)

        for _ in 0..<length
        {
            result.append(random())
        }

        return result
    }

    /// Generates an object array, or `nil` when ``bool()`` is `false`.
    public static func objArrayOrNull<T>(maxLength: Int, random: () -> T) -> [T]?
    {
        return bool() ? objArray(maxLength: maxLength, random: random) : nil
    }

    public static func byteObjArray(maxLength: Int) -> [Int8]
    {
        return objArray(maxLength: maxLength, random: byte)
    }

    public static func byteObjArrayOrNull(maxLength: Int) -> [Int8]?
    {
        return bool() ? byteObjArray(maxLength: maxLength) : nil
    }

    public static func uByteObjArray(maxLength: Int) -> [UInt8]
    {
        return objArray(maxLength: maxLength, random: uByte)
    }

    public static func uByteObjArrayOrNull(maxLength: Int) -> [UInt8]?
    {
        return bool() ? uByteObjArray(maxLength: maxLength) : nil
    }

    public static func shortObjArray(maxLength: Int) -> [Int16]
    {
        return objArray(maxLength: maxLength, random: short)
    }

    public static func shortObjArrayOrNull(maxLength: Int) -> [Int16]?
    {
        return bool() ? shortObjArray(maxLength: maxLength) : nil
    }

    public static func uShortObjArray(maxLength: Int) -> [UInt16]
    {
        return objArray(maxLength: maxLength, random: uShort)
    }

    public static func uShortObjArrayOrNull(maxLength: Int) -> [UInt16]?
    {
        return bool() ? uShortObjArray(maxLength: maxLength) : nil
    }

    public static func intObjArray(maxLength: Int) -> [Int]
    {
        return objArray(maxLength: maxLength, random: int)
    }

    public static func intObjArrayOrNull(maxLength: Int) -> [Int]?
    {
        return bool() ? intObjArray(maxLength: maxLength) : nil
    }

    public static func uIntObjArray(maxLength: Int) -> [UInt]
    {
        return objArray(maxLength: maxLength, random: uInt)
    }

    public static func uIntObjArrayOrNull(maxLength: Int) -> [UInt]?
    {
        return bool() ? uIntObjArray(maxLength: maxLength) : nil
    }

    public static func longObjArray(maxLength: Int) -> [Int64]
    {
        return objArray(maxLength: maxLength, random: long)
    }

    public static func longObjArrayOrNull(maxLength: Int) -> [Int64]?
    {
        return bool() ? longObjArray(maxLength: maxLength) : nil
    }

    public static func uLongObjArray(maxLength: Int) -> [UInt64]
    {
        return objArray(maxLength: maxLength, random: uLong)
    }

    public static func uLongObjArrayOrNull(maxLength: Int) -> [UInt64]?
    {
        return bool() ? uLongObjArray(maxLength: maxLength) : nil
    }

    public static func floatObjArray(maxLength: Int) -> [Float]
    {
        return objArray(maxLength: maxLength, random: float)
    }

    public static func floatObjArrayOrNull(maxLength: Int) -> [Float]?
    {
        return bool() ? floatObjArray(maxLength: maxLength) : nil
    }

    public static func doubleObjArray(maxLength: Int) -> [Double]
    {
        return objArray(maxLength: maxLength, random: double)
    }

    public static func doubleObjArrayOrNull(maxLength: Int) -> [Double]?
    {
        return bool() ? doubleObjArray(maxLength: maxLength) : nil
    }

    public static func boolObjArray(maxLength: Int) -> [Bool]
    {
        return objArray(maxLength: maxLength, random: bool)
    }

    public static func boolObjArrayOrNull(maxLength: Int) -> [Bool]?
    {
        return bool() ? boolObjArray(maxLength: maxLength) : nil
    }

    public static func charObjArray(maxLength: Int) -> [Character]
    {
        return objArray(maxLength: maxLength, random: char)
    }

    public static func charObjArrayOrNull(maxLength: Int) -> [Character]?
    {
        return bool() ? charObjArray(maxLength: maxLength) : nil
    }

    // MARK: - Primitive arrays

    public static func shortArray(maxLength: Int) -> [Int16]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in short() }
    }

    public static func shortArrayOrNull(maxLength: Int) -> [Int16]?
    {
        return bool() ? shortArray(maxLength: maxLength) : nil
    }

    public static func intArray(maxLength: Int) -> [Int]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in int() }
    }

    public static func intArrayOrNull(maxLength: Int) -> [Int]?
    {
        return bool() ? intArray(maxLength: maxLength) : nil
    }

    public static func longArray(maxLength: Int) -> [Int64]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in long() }
    }

    public static func longArrayOrNull(maxLength: Int) -> [Int64]?
    {
        return bool() ? longArray(maxLength: maxLength) : nil
    }

    public static func floatArray(maxLength: Int) -> [Float]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in float() }
    }

    public static func floatArrayOrNull(maxLength: Int) -> [Float]?
    {
        return bool() ? floatArray(maxLength: maxLength) : nil
    }

    public static func doubleArray(maxLength: Int) -> [Double]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in double() }
    }

    public static func doubleArrayOrNull(maxLength: Int) -> [Double]?
    {
        return bool() ? doubleArray(maxLength: maxLength) : nil
    }

    public static func boolArray(maxLength: Int) -> [Bool]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in bool() }
    }

    public static func boolArrayOrNull(maxLength: Int) -> [Bool]?
    {
        return bool() ? boolArray(maxLength: maxLength) : nil
    }

    public static func charArray(maxLength: Int) -> [Character]
    {
        let length = int(max: maxLength)
        return (0..<length).map { _ in char() }
    }

    public static func charArrayOrNull(maxLength: Int) -> [Character]?
    {
        return bool() ? charArray(maxLength: maxLength) : nil
    }

    // MARK: - Strings

    /// Generates a random ASCII letter string with length in `0..<maxLength`.
    public static func asciiLetters(maxLength: Int) -> String
    {
        return chars(maxLength: maxLength, ranges: [upperCase, lowerCase])
    }

    public static func asciiLettersOrNull(maxLength: Int) -> String?
    {
        return bool() ? asciiLetters(maxLength: maxLength) : nil
    }

    /// Generates a random digit string with length in `0..<maxLength`.
    public static func digits(maxLength: Int) -> String
    {
        return chars(maxLength: maxLength, ranges: [numbers])
    }

    public static func digitsOrNull(maxLength: Int) -> String?
    {
        return bool() ? digits(maxLength: maxLength) : nil
    }

    /// Generates a random ASCII letter or digit string with length in `0..<maxLength`.
    public static func asciiLettersOrNumbers(maxLength: Int) -> String
    {
        return chars(maxLength: maxLength, ranges: [upperCase, lowerCase, numbers])
    }

    public static func asciiLettersOrNumbersOrNull(maxLength: Int) -> String?
    {
        return bool() ? asciiLettersOrNumbers(maxLength: maxLength) : nil
    }

    /// Generates a random string of characters drawn from the given inclusive ranges.
    public static func chars(
        maxLength: Int,
        ranges: [(Character, Character)] = [(Character(UnicodeScalar(0)!), Character(UnicodeScalar(0x10FFFF)!))]) -> String
    {
        let length = int(max: maxLength)
        var result = ""
        result.reserveCapacity(length)

        while result.count < length
        {
            let candidate = char()
            if isCharacter(candidate, in: ranges)
            {
                result.append(candidate)
            }
        }

        return result
    }

    public static func charsOrNull(
        maxLength: Int,
        ranges: [(Character, Character)] = [(Character(UnicodeScalar(0)!), Character(UnicodeScalar(0x10FFFF)!))]) -> String?
    {
        return bool() ? chars(maxLength: maxLength, ranges: ranges) : nil
    }

    /// Generates a random ASCII word (letters only) with length in `0..<maxLength`.
    public static func asciiWord(maxLength: Int) -> String
    {
        return asciiLetters(maxLength: maxLength)
    }

    public static func asciiWordOrNull(maxLength: Int) -> String?
    {
        return bool() ? asciiWord(maxLength: maxLength) : nil
    }

    /// Generates random ASCII words separated by spaces.
    public static func asciiWords(maxNumberOfWords: Int, maxWordLength: Int) -> String
    {
        let wordCount = int(max: maxNumberOfWords)
        var result = ""
        result.reserveCapacity(wordCount * max(maxWordLength, 1))

        for _ in 0..<wordCount
        {
            result.append(asciiWord(maxLength: maxWordLength))
            result.append(" ")
        }

        return result
    }

    public static func asciiWordsOrNull(maxNumberOfWords: Int, maxWordLength: Int) -> String?
    {
        return bool() ? asciiWords(maxNumberOfWords: maxNumberOfWords, maxWordLength: maxWordLength) : nil
    }

    // MARK: - Private

    private static func loadInteger<T: FixedWidthInteger>(_ type: T.Type) -> T
    {
        let data = bytes(length: MemoryLayout<T>.size)
        return data.withUnsafeBytes { T(bigEndian: $0.load(as: T.self)) }
    }

    private static func secureUniform(upperBound: UInt32) -> UInt32
    {
        return UInt32(truncatingIfNeeded: secureUniform(span: UInt64(upperBound)))
    }

    private static func secureUniform(span: UInt64) -> UInt64
    {
        guard span > 1 else
        {
            return 0
        }

        let threshold = (UInt64.max / span) * span
        var value: UInt64 = 0

        repeat
        {
            value = loadInteger(UInt64.self)
        }
        while value >= threshold

        return value % span
    }

    private static func isCharacter(_ character: Character, in ranges: [(Character, Character)]) -> Bool
    {
        for range in ranges
        {
            if character >= range.0 && character <= range.1
            {
                return true
            }
        }

        return false
    }
}
