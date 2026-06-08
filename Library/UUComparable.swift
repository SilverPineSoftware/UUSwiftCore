//
//  UUComparable.swift
//  UUSwiftCore
//
//  Created by Kim Vertner on 10/14/21.
//

import Foundation


extension Comparable {
    
    //Force a value to a specific range. Anything comparable can be clamped!
    func uuClamp(low: Self, high: Self) -> Self {
        if (self > high) {
            return high
        } else if (self < low) {
            return low
        }
        
        return self
    }
}
