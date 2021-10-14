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
    
    func uuData(at index: Int, count: Int) -> Data
    {
        let upperIndex = ((index + count) > self.count) ? self.count : index + count
        return self.subdata(in: index..<upperIndex)
    }
    
    func uuInteger<T: FixedWidthInteger>(at index: Int) -> T
    {
        return uuData(at: index, count: MemoryLayout<T>.size).withUnsafeBytes{ $0.load(as: T.self) }
    }
    
    func uuUInt8At(at index: Int) -> UInt8
    {
        return uuInteger(at: index)
    }
    
    func uuUInt16At(at index: Int) -> UInt16
    {
        return uuInteger(at: index)
    }
    
    func uuUInt32At(at index: Int) -> UInt32
    {
        return uuInteger(at: index)
    }
    
    func uuUInt64At(at index: Int) -> UInt64
    {
        return uuInteger(at: index)
    }
    
    func uuInt8At(at index: Int) -> Int8
    {
        return uuInteger(at: index)
    }
    
    func uuInt16At(at index: Int) -> Int16
    {
        return uuInteger(at: index)
    }
    
    func uuInt32At(at index: Int) -> Int32
    {
        return uuInteger(at: index)
    }
    
    func uuInt64At(at index: Int) -> Int64
    {
        return uuInteger(at: index)
    }
    
    func uuString(at index: Int, count: Int, with encoding: String.Encoding) -> String?
    {
        return String(bytes: uuData(at: index, count: count), encoding: encoding)
    }
    
    // MARK: Mutating Functions
    
    mutating func uuAppendInteger<T: FixedWidthInteger>(_ value: T)
    {
        withUnsafePointer(to: value)
        { ptr in
            append(UnsafeBufferPointer(start: ptr, count: MemoryLayout<T>.size))
        }
    }
    
    mutating func uuAppendUInt8(_ value: UInt8)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendUInt16(_ value: UInt16)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendUInt32(_ value: UInt32)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendUInt64(_ value: UInt64)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendInt8(_ value: Int8)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendInt16(_ value: Int16)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendInt32(_ value: Int32)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendInt64(_ value: Int64)
    {
        uuAppendInteger(value)
    }
    
    mutating func uuAppendString(_ value: String?, encoding: String.Encoding = .utf8)
    {
        if let actual = value, let data = actual.data(using: encoding)
        {
            append(data)
        }
    }
    
    mutating func uuReplaceInteger<T: FixedWidthInteger>(_ value: T, at index: Int)
    {
        withUnsafePointer(to: value)
        { ptr in
            let count = MemoryLayout<T>.size
            let tmp = Data(buffer: UnsafeBufferPointer(start: ptr, count: MemoryLayout<T>.size))
            replaceSubrange(index..<count, with: tmp)
        }
    }
    
    mutating func uuReplaceUInt8(_ value: UInt8, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceUInt16(_ value: UInt16, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceUInt32(_ value: UInt32, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceUInt64(_ value: UInt64, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceInt8(_ value: Int8, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceInt16(_ value: Int16, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceInt32(_ value: Int32, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
    
    mutating func uuReplaceInt64(_ value: Int64, at index: Int)
    {
        uuReplaceInteger(value, at: index)
    }
}
