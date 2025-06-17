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
}
