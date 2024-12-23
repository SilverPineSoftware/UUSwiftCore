//
//  UUJsonTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 11/30/24.
//

import XCTest
import UUSwiftCore
import UUSwiftTestCore

final class UUJsonTests: XCTestCase
{
    func testDictionaryToJsonString() throws
    {
        let d = ["a": 1, "b": 2]
        let jsonString = d.uuToJsonString()
        XCTAssertNotNil(jsonString)
        UUTestLog("Dictionary as JSON: \(jsonString)")
    }
    
    func testArrayToJsonString() throws
    {
        let a = ["foo", "bar", "baz"]
        let jsonString = a.uuToJsonString()
        XCTAssertNotNil(jsonString)
        UUTestLog("Array as JSON: \(jsonString)")
    }
    
    func testEncodableToJsonString() throws
    {
        class MyObject: Codable
        {
            let a: Int
            let b: Int
            
            init(a: Int, b: Int)
            {
                self.a = a
                self.b = b
            }
        }
        
        let d = MyObject(a: 3, b: 4)
        let jsonString = d.uuToJsonString()
        XCTAssertNotNil(jsonString)
        UUTestLog("Encodable as JSON: \(jsonString)")
    }
}
