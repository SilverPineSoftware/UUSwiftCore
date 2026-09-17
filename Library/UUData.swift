//
//  UUData.swift
//  Useful Utilities - Extensions for Data
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//
import Foundation
import CryptoKit

fileprivate let LOG_TAG : String = "UUData"

public enum UUByteOrder
{
    case littleEndian
    case bigEndian
}

/// Validation failures from Data padding and replacement operations.
public enum UUDataError: Error, Equatable, Sendable
{
    case invalidLength(Int)
    case invalidBlockSize(Int)
    case replacementOutOfBounds(index: Int, byteCount: Int, dataCount: Int)
    case paddedLengthOverflow
}

public extension Data
{
    // Return hex string representation of data
    //
    func uuToHexString() -> String
    {
        let sb : NSMutableString = NSMutableString()
        
        for byte in self
        {
            sb.appendFormat("%02X", byte)
        }
        
        return sb as String
    }
    
    /// Returns a space-separated binary string of each byte.
    func uuToBinaryString() -> String
    {
        return self
            .map { $0.uuToBinaryString() }
            .joined(separator: " ")
    }
    
    // Return JSON object of the data
    //
    func uuToJson() -> Any?
    {
        do
        {
            return try JSONSerialization.jsonObject(with: self, options: [])
        }
        catch (let err)
        {
            UULog.error(tag: LOG_TAG, message: "Error deserializing JSON: \(String(describing: err))")
        }
        
        return nil
    }
    
    /// Validates and reserializes a JSON object or array as UTF-8 text.
    /// Formatting and key order may change. Returns an empty string on failure.
    func uuToJsonString() -> String
    {
        guard let json = uuToJson() else
        {
            return ""
        }

        do
        {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            return String(decoding: data, as: UTF8.self)
        }
        catch
        {
            UULog.error(tag: LOG_TAG, message: "Error serializing JSON: \(error)")
            return ""
        }
    }
    
    /**
     Reverses the byte array
     */
    func uuReversed() -> Data
    {
        return Data.init(self.reversed())
    }
    
    /**
     Creates a byte array containing the data
     */
    var uuBytes: [UInt8]
    {
        return [UInt8](self)
    }
    
    /// Reads bytes at a relative offset from the beginning, including for sliced Data.
    /// Truncates the requested count to the available bytes. Returns nil for negative
    /// counts or offsets outside `0...self.count`; an offset at the end returns empty Data.
    func uuData(at index: Int, count: Int) -> Data?
    {
        guard index >= 0, index <= self.count, count >= 0 else
        {
            return nil
        }

        let length = Swift.min(count, self.count - index)
        let lowerIndex = self.index(startIndex, offsetBy: index)
        let upperIndex = self.index(lowerIndex, offsetBy: length)
        return subdata(in: lowerIndex..<upperIndex)
    }

    /// Reads an integer at a relative byte offset using the specified byte order.
    /// Returns nil if the offset is invalid or the complete value is unavailable.
    func uuInteger<T: FixedWidthInteger>(order: UUByteOrder, at index: Int) -> T?
    {
        let size = MemoryLayout<T>.size
        guard index >= 0, index <= count, size <= count - index else
        {
            return nil
        }
        
        let rawValue = withUnsafeBytes
        {
            $0.loadUnaligned(fromByteOffset: index, as: T.self)
        }
        
        switch order
        {
            case .bigEndian:
                return T(bigEndian: rawValue)

            case .littleEndian:
                return T(littleEndian: rawValue)
        }
    }
    
    /// Reads one byte at a relative offset, returning nil when out of bounds.
    func uuUInt8(at index: Int) -> UInt8?
    {
        guard index >= 0, index < count else
        {
            return nil
        }

        return self[self.index(startIndex, offsetBy: index)]
    }

    func uuUInt16(order: UUByteOrder, at index: Int) -> UInt16?
    {
        return uuInteger(order: order, at: index)
    }
    
    /// Reads three bytes at a relative offset, returning nil if fewer are available.
    func uuUInt24(order: UUByteOrder, at index: Int) -> UInt32?
    {
        guard index >= 0, index <= count, 3 <= count - index else
        {
            return nil
        }

        let firstIndex = self.index(startIndex, offsetBy: index)
        let first = UInt32(self[firstIndex])
        let second = UInt32(self[self.index(firstIndex, offsetBy: 1)])
        let third = UInt32(self[self.index(firstIndex, offsetBy: 2)])

        switch order
        {
            case .littleEndian:
                return first | (second << 8) | (third << 16)

            case .bigEndian:
                return (first << 16) | (second << 8) | third
        }
    }

    func uuUInt32(order: UUByteOrder, at index: Int) -> UInt32?
    {
        return uuInteger(order: order, at: index)
    }
    
    func uuUInt64(order: UUByteOrder, at index: Int) -> UInt64?
    {
        return uuInteger(order: order, at: index)
    }
    
    /// Reads one byte at a relative offset and interprets its bits as a signed integer.
    func uuInt8(at index: Int) -> Int8?
    {
        return uuUInt8(at: index).map { Int8(bitPattern: $0) }
    }

    func uuInt16(order: UUByteOrder, at index: Int) -> Int16?
    {
        return uuInteger(order: order, at: index)
    }
    
    func uuInt32(order: UUByteOrder, at index: Int) -> Int32?
    {
        return uuInteger(order: order, at: index)
    }
    
    func uuInt64(order: UUByteOrder, at index: Int) -> Int64?
    {
        return uuInteger(order: order, at: index)
    }
    
    func uuString(at index: Int, count: Int, with encoding: String.Encoding) -> String?
    {
        guard let data = uuData(at: index, count: count) else
        {
            return nil
        }
        
        return String(bytes: data, encoding: encoding)
    }
    
    /// Returns a new Data that is exactly `toLength` bytes long,
    /// padding with 0x00 bytes on the right if needed, or truncating
    /// if self.count > toLength.
    ///
    /// - Parameter toLength: Desired total length (must be >= 0).
    /// - Returns: The padded data, or a failure for a negative length.
    func uuPadded(toLength: Int) -> Result<Data, Error>
    {
        guard toLength >= 0 else
        {
            return .failure(UUDataError.invalidLength(toLength))
        }

        // If already longer, just truncate:
        if count >= toLength
        {
            return .success(Data(self.prefix(toLength)))
        }
        
        // Otherwise, append zero bytes:
        var result = self
        result.append(Data(count: toLength - count))
        return .success(result)
    }
    
    /// Returns a new `Data` whose length is padded with 0x00 bytes
    /// up to the next multiple of `blockSize`. If `self.count` is already
    /// a multiple of `blockSize`, returns `self` unchanged.
    ///
    /// - Parameter blockSize: The block size to pad to (must be > 0).
    /// - Returns: The padded data, or a failure for a nonpositive block size or length overflow.
    func uuPadded(toBlockSize blockSize: Int) -> Result<Data, Error>
    {
        guard blockSize > 0 else
        {
            return .failure(UUDataError.invalidBlockSize(blockSize))
        }

        let remainder = count % blockSize
        
        // If already aligned, no padding needed
        guard remainder != 0 else
        {
            return .success(self)
        }
        
        // Number of zero bytes to append
        let padCount = blockSize - remainder
        guard padCount <= Int.max - count else
        {
            return .failure(UUDataError.paddedLengthOverflow)
        }
        var result = self
        result.append(Data(count: padCount))
        return .success(result)
    }
    
    /// Returns a new `Data` where each byte is the XOR of the corresponding bytes
    /// in `self` and `other`. If their lengths differ, returns the original bytes unchanged.
    ///
    /// - Parameter other: The Data to XOR against.
    /// - Returns: A new Data containing the XOR result.
    func uuXor(with other: Data) -> Data
    {
        guard count == other.count else
        {
            return Data(self)
        }

        return Data(zip(self, other).map { $0 ^ $1 })
    }
    
    // MARK: Safe getters
    
    func uuSafeData(at index: Int, count: Int) -> Data
    {
        return uuData(at: index, count: count) ?? Data()
    }
    
    func uuSafeUInt8(at index: Int, defaultValue: UInt8 = 0) -> UInt8
    {
        return uuUInt8(at: index) ?? defaultValue
    }
    
    func uuSafeUInt16(order: UUByteOrder, at index: Int, defaultValue: UInt16 = 0) -> UInt16
    {
        return uuInteger(order: order, at: index) ?? defaultValue
    }
    
    func uuSafeUInt32(order: UUByteOrder, at index: Int, defaultValue: UInt32 = 0) -> UInt32
    {
        return uuInteger(order: order, at: index) ?? defaultValue
    }
    
    func uuSafeUInt64(order: UUByteOrder, at index: Int, defaultValue: UInt64 = 0) -> UInt64
    {
        return uuInteger(order: order, at: index) ?? defaultValue
    }
    
    func uuSafeInt8(at index: Int, defaultValue: Int8 = 0) -> Int8
    {
        return uuInt8(at: index) ?? defaultValue
    }
    
    func uuSafeInt16(order: UUByteOrder, at index: Int, defaultValue: Int16 = 0) -> Int16
    {
        return uuInteger(order: order, at: index) ?? defaultValue
    }
    
    func uuSafeInt32(order: UUByteOrder, at index: Int, defaultValue: Int32 = 0) -> Int32
    {
        return uuInteger(order: order, at: index) ?? defaultValue
    }
    
    func uuSafeInt64(order: UUByteOrder, at index: Int, defaultValue: Int64 = 0) -> Int64
    {
        return uuInteger(order: order, at: index) ?? defaultValue
    }
    
    func uuSafeString(at index: Int, count: Int, with encoding: String.Encoding, defaultValue: String = "") -> String
    {
        return uuString(at: index, count: count, with: encoding) ?? defaultValue
    }
    
    // MARK: Mutating Functions
    
    /// Appends the integer's bytes in native byte order.
    /// Pass `value.littleEndian` or `value.bigEndian` when writing a defined binary format.
    mutating func uuAppend<T: FixedWidthInteger>(_ value: T)
    {
        Swift.withUnsafeBytes(of: value, { append(contentsOf: $0) })
    }
    
    /// Appends the encoded string. Nil values and encoding failures leave the data unchanged.
    mutating func uuAppend(_ value: String?, encoding: String.Encoding = .utf8)
    {
        if let actual = value, let data = actual.data(using: encoding)
        {
            append(data)
        }
    }
    
    /// Replaces an integer at a relative byte offset, returning failure if it does not fit.
    /// On failure, the data is unchanged.
    /// Writes native byte order. Pass `value.littleEndian` or `value.bigEndian`
    /// when writing a defined binary format.
    mutating func uuReplace<T: FixedWidthInteger>(_ value: T, at index: Int) -> Result<Void, Error>
    {
        let size = MemoryLayout<T>.size
        guard index >= 0, index <= count, size <= count - index else
        {
            return .failure(UUDataError.replacementOutOfBounds(index: index, byteCount: size, dataCount: count))
        }

        Swift.withUnsafeBytes(of: value)
        { buffer in
            let lowerIndex = self.index(startIndex, offsetBy: index)
            let upperIndex = self.index(lowerIndex, offsetBy: buffer.count)
            replaceSubrange(lowerIndex..<upperIndex, with: buffer)
        }
        return .success(())
    }

    /// Sets every byte in this `Data` instance to zero.
    ///
    /// This method uses `resetBytes(in:)` to overwrite all bytes
    /// in the range `startIndex..<endIndex` with `0x00`. After calling this,
    /// the entire buffer is cleared.
    mutating func uuReset()
    {
        resetBytes(in: startIndex..<endIndex)
    }

    /// Sets every byte in this `Data` instance to a specified value.
    ///
    /// - Parameter value: The `UInt8` value to write into each byte.
    ///
    /// This method replaces the entire contents of `self` (range `startIndex..<endIndex`)
    /// with a sequence of `count` copies of `value`. After calling this,
    /// every byte in the buffer will equal `value`.
    mutating func uuSetAll(to value: UInt8)
    {
        replaceSubrange(startIndex..<endIndex, with: repeatElement(value, count: self.count))
    }
    
    // MARK: Nibble Support
    
    func uuHighNibble(at index: Int) -> UInt8?
    {
        return uuUInt8(at: index).map { $0 >> 4 }
    }

    func uuLowNibble(at index: Int) -> UInt8?
    {
        return uuUInt8(at: index).map { $0 & 0x0F }
    }

    // MARK: BCD Support

    func uuBCD8(at index: Int) -> UInt8?
    {
        guard let byte = uuUInt8(at: index) else
        {
            return nil
        }

        let highNibble = byte >> 4
        let lowNibble = byte & 0x0F
        guard highNibble <= 9, lowNibble <= 9 else
        {
            return nil
        }

        return (highNibble * 10) + lowNibble
    }

    func uuBCD16(at index: Int) -> UInt16?
    {
        guard let data1 = uuBCD8(at: index),
              let data2 = uuBCD8(at: index + 1) else
        {
            return nil
        }
        
        return (UInt16(data1) * 100) + UInt16(data2)
    }
    
    func uuBCD24(at index: Int) -> UInt32?
    {
        guard let data1 = uuBCD8(at: index),
              let data2 = uuBCD8(at: index + 1),
              let data3 = uuBCD8(at: index + 2) else
        {
            return nil
        }
        
        return (UInt32(data1) * 10000) + (UInt32(data2) * 100) + UInt32(data3)
    }
    
    func uuBCD32(at index: Int) -> UInt32?
    {
        guard let data1 = uuBCD16(at: index),
              let data2 = uuBCD16(at: index + 2) else
        {
            return nil
        }
        
        return (UInt32(data1) * 10000) + UInt32(data2)
    }
    
    /// Splits into chunks, retaining a shorter final chunk. Nonpositive sizes return no chunks.
    func uuSlice(chunkSize: Int) -> [Data]
    {
        guard chunkSize > 0 else
        {
            return []
        }

        var chunks: [Data] = []
        
        var index = 0
        
        while (index < count)
        {
            if let chunk = uuData(at: index, count: chunkSize)
            {
                chunks.append(chunk)
            }
            
            index += Swift.min(chunkSize, count - index)
        }
        
        return chunks   
    }
    
    // MARK: - SHA

    /// Computes the SHA-256 digest of the data (FIPS 180-4).
    ///
    /// Returns a 32-byte digest. Implemented with CryptoKit ``SHA256``.
    func uuSha256() -> Data
    {
        return Data(SHA256.hash(data: self))
    }

    /// Computes the SHA-384 digest of the data (FIPS 180-4).
    ///
    /// Returns a 48-byte digest. Implemented with CryptoKit ``SHA384``.
    func uuSha384() -> Data
    {
        return Data(SHA384.hash(data: self))
    }

    /// Computes the SHA-512 digest of the data (FIPS 180-4).
    ///
    /// Returns a 64-byte digest. Implemented with CryptoKit ``SHA512``.
    func uuSha512() -> Data
    {
        return Data(SHA512.hash(data: self))
    }
}
