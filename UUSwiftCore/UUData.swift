//
//  UUData.swift
//  Useful Utilities - Extensions for Data
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//
#if os(macOS)
	import AppKit
#else
	import UIKit
#endif

public extension Data
{
    // Return hex string representation of data
    //
    func uuToHexString() -> String
    {
        let sb : NSMutableString = NSMutableString()
        
        if (self.count > 0)
        {
            for index in 0...(self.count - 1)
            {
                sb.appendFormat("%02X", self[index])
            }
        }
        
        return sb as String
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
            UUDebugLog("Error deserializing JSON: %@", String(describing: err))
        }
        
        return nil
    }
    
    // Returns JSON string representation of the data
    //
    func uuToJsonString() -> String
    {
        let json = uuToJson()
        return String(format: "%@", (json as? CVarArg) ?? "")
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
    
    func uuData(at index: Int, count: Int) -> Data?
    {
        guard index >= 0 else
        {
            return nil
        }
        
        let upperIndex = ((index + count) > self.count) ? self.count : index + count
        
        guard index <= upperIndex else
        {
            return nil
        }
        
        return subdata(in: index..<upperIndex)
    }
    
    func uuInteger<T: FixedWidthInteger>(at index: Int) -> T?
    {
        let size = MemoryLayout<T>.size
        guard let subData = uuData(at: index, count: size),
              !subData.isEmpty,
              subData.count >= size else
        {
            return nil
        }
        
        return subData.withUnsafeBytes{ $0.load(as: T.self) }
    }
    
    func uuUInt8(at index: Int) -> UInt8?
    {
        return uuInteger(at: index)
    }
    
    func uuUInt16(at index: Int) -> UInt16?
    {
        return uuInteger(at: index)
    }
    
    func uuUInt32(at index: Int) -> UInt32?
    {
        return uuInteger(at: index)
    }
    
    func uuUInt64(at index: Int) -> UInt64?
    {
        return uuInteger(at: index)
    }
    
    func uuInt8(at index: Int) -> Int8?
    {
        return uuInteger(at: index)
    }
    
    func uuInt16(at index: Int) -> Int16?
    {
        return uuInteger(at: index)
    }
    
    func uuInt32(at index: Int) -> Int32?
    {
        return uuInteger(at: index)
    }
    
    func uuInt64(at index: Int) -> Int64?
    {
        return uuInteger(at: index)
    }
    
    func uuString(at index: Int, count: Int, with encoding: String.Encoding) -> String?
    {
        guard let data = uuData(at: index, count: count) else
        {
            return nil
        }
        
        return String(bytes: data, encoding: encoding)
    }
    
    // MARK: Safe gettors
    
    func uuSafeData(at index: Int, count: Int) -> Data
    {
        return uuData(at: index, count: count) ?? Data()
    }
    
    func uuSafeUInt8(at index: Int, defaultValue: UInt8 = 0) -> UInt8
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeUInt16(at index: Int, defaultValue: UInt16 = 0) -> UInt16
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeUInt32(at index: Int, defaultValue: UInt32 = 0) -> UInt32
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeUInt64(at index: Int, defaultValue: UInt64 = 0) -> UInt64
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeInt8(at index: Int, defaultValue: Int8 = 0) -> Int8
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeInt16(at index: Int, defaultValue: Int16 = 0) -> Int16
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeInt32(at index: Int, defaultValue: Int32 = 0) -> Int32
    {
        return uuInteger(at: index) ?? defaultValue
    }
    
    func uuSafeInt64(at index: Int, defaultValue: Int64 = 0) -> Int64
    {
        return uuInteger(at: index) ?? defaultValue
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
    
    mutating func uuReplace<T: FixedWidthInteger>(_ value: T, at index: Int)
    {
        Swift.withUnsafeBytes(of: value)
        { buffer in
            replaceSubrange(index..<(index+buffer.count), with: buffer)
        }
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
}
