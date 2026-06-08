
//
//  UUArrayTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 07/28/25.
//

import XCTest
@testable import UUSwiftCore

class UUArrayTests: XCTestCase
{
    func test_uuSlice()
    {
        let testData: [([Int],Int,[[Int]])] =
        [
            ([0,1,2,3,4,5,6,7,8,9], 3, [ [0,1,2],
                                         [3,4,5],
                                         [6,7,8],
                                         [9]]),
            
            ([0,1,2,3,4,5,6,7,8,9], 5, [ [0,1,2,3,4],
                                         [5,6,7,8,9]]),
            
            ([0,1,2,3,4,5,6,7,8,9], 20, [[0,1,2,3,4,5,6,7,8,9]]),
            
            ([0,1,2,3,4,5,6,7,8,9], -1, []),
        ]
        
        for td in testData
        {
            let actual = td.0.uuSlice(chunkSize: td.1)
            XCTAssertEqual(td.2, actual)
        }
    }
}
