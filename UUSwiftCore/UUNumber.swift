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
    
    /// Returns a copy of `self` with the bit at `index` set or cleared.
    ///
    /// - Parameters:
    ///   - index: The bit position to modify (0 ..< `Self.bitWidth`).
    ///   - to:  Pass `true` to set the bit (1), or `false` to clear it (0).
    /// - Returns: A new integer with that bit modified, or `self` if `index` is out of bounds.
    func uuSetBit(to: Bool, at index: Int) -> Self
    {
        // If the index is invalid, return unchanged
        guard (0..<Self.bitWidth).contains(index) else
        {
            return self
        }

        let mask: Self = 1 << index
        return to
            ? (self | mask)   // set bit
            : (self & ~mask)  // clear bit
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
    
    /// Converts a number into a BCD byte
    /// - Returns: A bcd number or nil
    func uuToBcd8() -> Self?
    {
        guard self >= 0 && self <= 99 else
        {
            return nil
        }
        
        let highNibble: Self = self / 10
        let lowNibble: Self = self % 10
        let bcd: Self = (highNibble << 4) | lowNibble
        return bcd
    }
    
    /// Converts a number from a BCD byte to a number
    /// - Returns: A bcd number or nil
    func uuFromBcd8() -> Self
    {
        let highNibble = (self & 0xF0) >> 4
        let lowNibble = self & 0x0F
        let number: Self = highNibble * 10 + lowNibble
        
        return number
    }
    
    /// Determines whether the integer value represents a leap year.
    ///
    /// Leap years occur according to the following rules:
    /// 1. Years divisible by 4 are leap years.
    /// 2. However, years divisible by 100 are **not** leap years.
    /// 3. Exception: years divisible by 400 **are** leap years.
    ///
    /// Examples:
    /// ```swift
    /// 2000.uuIsLeapYear // true  (divisible by 400)
    /// 1900.uuIsLeapYear // false (divisible by 100 but not 400)
    /// 2024.uuIsLeapYear // true  (divisible by 4, not by 100)
    /// 2025.uuIsLeapYear // false (not divisible by 4)
    /// ```
    ///
    /// This property is typically used on year values (e.g., `Calendar.current.component(.year, from: Date())`).
    var uuIsLeapYear: Bool
    {
        // Leap year rules:
        // 1. Divisible by 4 → leap year
        // 2. Except if divisible by 100 → not leap year
        // 3. Except if divisible by 400 → leap year again
        if self % 400 == 0
        {
            return true
        }
        else if self % 100 == 0
        {
            return false
        }
        else
        {
            return self % 4 == 0
        }
    }
}
