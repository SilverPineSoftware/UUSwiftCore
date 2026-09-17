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
    
    // Returns JSON string representation of the data
    //
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
     Casts the data object to a raw byte array
     */
    var uuBytes: [UInt8]
    {
        return [UInt8](self)
    }
    
    /// Reads bytes at a relative offset from the beginning, including for sliced Data.
    /// Truncates the requested count to the available bytes. Returns nil for negative
    /// counts or offsets outside 0...count; an offset at the end returns empty Data.
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

    func uuInteger<T: FixedWidthInteger>(order: UUByteOrder, at index: Int) -> T?
    {
        let size = MemoryLayout<T>.size
        guard let subData = uuData(at: index, count: size),
              !subData.isEmpty,
              subData.count >= size else
        {
            return nil
        }
        
        let rawValue = subData.withUnsafeBytes{ $0.loadUnaligned(as: T.self) }
        
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
    
    func uuUInt24(order: UUByteOrder, at index: Int) -> UInt32?
    {
        guard let bytes = uuData(at: index, count: 3)?.uuBytes, bytes.count == 3 else
        {
            return nil
        }
        
        let byteOne = bytes[0]
        let byteTwo = bytes[1]
        let byteThree = bytes[2]
        
        switch (order)
        {
            case .littleEndian:
                let part1 = (UInt32(byteOne) & 0x000000FF)
                let part2 = (UInt32(byteTwo) << 8) & 0x0000FF00
                let part3 = (UInt32(byteThree) << 16) & 0x00FF0000
                
                return (part1 | part2 | part3)
                
            case .bigEndian:
            
                let part1 = (UInt32(byteThree) & 0x000000FF)
                let part2 = (UInt32(byteTwo) << 8) & 0x0000FF00
                let part3 = (UInt32(byteOne) << 16) & 0x00FF0000
                
                return (part1 | part2 | part3)
                
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
    /// - Parameter toLength: Desired total length.
    /// - Returns: A Data of length `toLength`.
    func uuPadded(toLength: Int) -> Data
    {
        // If already longer, just truncate:
        if count >= toLength
        {
            return self.prefix(toLength)
        }
        
        // Otherwise, append zero bytes:
        var result = self
        result.append(Data(count: toLength - count))
        return result
    }
    
    /// Returns a new `Data` whose length is padded with 0x00 bytes
    /// up to the next multiple of `blockSize`. If `self.count` is already
    /// a multiple of `blockSize`, returns `self` unchanged.
    ///
    /// - Parameter blockSize: The block size to pad to (must be > 0).
    /// - Returns: A `Data` object whose length is a multiple of `blockSize`.
    func uuPadded(toBlockSize blockSize: Int) -> Data
    {
        let remainder = count % blockSize
        
        // If already aligned, no padding needed
        guard remainder != 0 else
        {
            return self
        }
        
        // Number of zero bytes to append
        let padCount = blockSize - remainder
        var result = self
        result.append(Data(count: padCount))
        return result
    }
    
    /// Returns a new `Data` where each byte is the XOR of the corresponding bytes
    /// in `self` and `other`. Both Data objects must be the same length.
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
    
    // MARK: Safe gettors
    
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
    
    mutating func uuAppend<T: FixedWidthInteger>(_ value: T)
    {
        Swift.withUnsafeBytes(of: value, { append(contentsOf: $0) })
    }
    
    mutating func uuAppend(_ value: String?, encoding: String.Encoding = .utf8)
    {
        if let actual = value, let data = actual.data(using: encoding)
        {
            append(data)
        }
    }
    
    /// Replaces an integer at a relative byte offset; the entire value must fit.
    mutating func uuReplace<T: FixedWidthInteger>(_ value: T, at index: Int)
    {
        Swift.withUnsafeBytes(of: value)
        { buffer in
            precondition(index >= 0 && index <= count && buffer.count <= count - index,
                         "Replacement must fit within the data")
            let lowerIndex = self.index(startIndex, offsetBy: index)
            let upperIndex = self.index(lowerIndex, offsetBy: buffer.count)
            replaceSubrange(lowerIndex..<upperIndex, with: buffer)
        }
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
        guard let data = self.uuUInt8(at: index) else
        {
            return nil
        }
        
        return ((data & 0xF0) >> 4)
    }
    
    func uuLowNibble(at index: Int) -> UInt8?
    {
        guard let data = self.uuUInt8(at: index) else
        {
            return nil
        }
        
        return ((data & 0x0F) >> 0)
    }
    
    // MARK: BCD Support
    
    func uuBCD8(at index: Int ) -> UInt8?
    {
        guard let highNibble = uuHighNibble(at: index),
              highNibble <= 9,
              let lowNibble = uuLowNibble(at: index),
              lowNibble <= 9 else
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
