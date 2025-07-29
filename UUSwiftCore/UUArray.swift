//
//  UUArray.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 7/28/25.
//

import Foundation

public extension Array
{
    /// Splits the array into chunks of up to `chunkSize` bytes.
    ///
    /// - Parameter chunkSize: Maximum size of each chunk.
    /// - Returns: An array of `Element`, each constructed from up to `chunkSize` bytes.
    func uuSlice(chunkSize: Int) -> [[Element]]
    {
        guard chunkSize > 0 else
        {
            return []
        }

        var chunks: [[Element]] = []
        var index = 0

        while index < count
        {
            // how many left in the array
            let length = Swift.min(chunkSize, count - index)
            
            // slice out the sub‐array
            let slice = self[index..<index + length]
            
            // wrap in Data and append
            chunks.append(Array(slice))
            index += chunkSize
        }

        return chunks
    }
}
