//
//  UUCollection.swift
//  UUSwiftCore
//
//  Created by Kim Vertner on 10/14/21.
//

import Foundation


public extension Collection {
    
    //Prevents index out of range fatal error
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
