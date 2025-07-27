//
//  UUNumber.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/11/25.
//

import Foundation

public extension FixedWidthInteger
{
    /// Returns this integer clamped to the given minimum and maximum.
    ///
    /// - Parameters:
    ///   - lower: The minimum allowable value.
    ///   - upper: The maximum allowable value.
    /// - Returns: `lower` if `self < lower`, `upper` if `self > upper`, otherwise `self`.
    func uuClamp(min lower: Self, max upper: Self) -> Self
    {
        if (self < lower)
        {
            return lower
        }
        
        if (self > upper)
        {
            return upper
        }
        
        return self
    }
    
    /// The number of bytes required to store values of this integer **type**.
    ///
    /// This is equivalent to calling `MemoryLayout<Self>.size`.
    ///
    static var uuByteSize: Int
    {
        MemoryLayout<Self>.size
    }

    /// The number of bytes required to store this integer **instance**.
    ///
    /// This is equivalent to calling `MemoryLayout.size(ofValue:)`.
    ///
    var uuByteSize: Int
    {
        MemoryLayout<Self>.size
    }
    
    /// Returns a copy of `self` with the bit at `index` cleared (set to 0).
    ///
    /// - Parameter index: The bit position to clear, in 0 ..< Self.bitWidth.
    /// - Returns: A new integer with that bit cleared.
    func uuClearBit(at index: Int) -> Self
    {
        // If the index is invalid, just return self unchanged
        guard (0..<Self.bitWidth).contains(index) else
        {
            return self
        }
        
        let mask: Self = 1 << index
        return self & ~mask
    }
    
    /// Returns a copy of `self` with the bit at `index` set (to 1).
    ///
    /// - Parameter index: The bit position to set, in 0 ..< Self.bitWidth.
    /// - Returns: A new integer with that bit set.
    func uuSetBit(at index: Int) -> Self
    {
        // If the index is invalid, just return self unchanged
        guard (0..<Self.bitWidth).contains(index) else
        {
            return self
        }
        
        let mask: Self = 1 << index
        return self | mask
    }

    /// Returns a copy of `self` with the bit at `index` XOR’d (toggled).
    ///
    /// - Parameter index: The bit position to toggle, in 0 ..< Self.bitWidth.
    /// - Returns: A new integer with that bit toggled.
    func uuXorBit(at index: Int) -> Self
    {
        // If the index is invalid, just return self unchanged
        guard (0..<Self.bitWidth).contains(index) else
        {
            return self
        }
        
        let mask: Self = 1 << index
        return self ^ mask
    }
}
