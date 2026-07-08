//
//  UUThreadTests.swift
//  UUSwiftCore
//

import Foundation
import XCTest
@testable import UUSwiftCore

final class UUThreadSafeArrayTests: XCTestCase
{
    func test_threadSafeArray_appendPrependAndRemove()
    {
        let array = UUThreadSafeArray<Int>()

        array.append(2)
        array.prepend(1)
        array.append(3)

        XCTAssertEqual(array.count, 3)
        XCTAssertTrue(array.contains(2))
        XCTAssertEqual(array.removeFirst(), 1)
        XCTAssertEqual(array.removeLast(), 3)
        XCTAssertEqual(array.popLast(), 2)
        XCTAssertNil(array.popLast())
    }

    func test_threadSafeArray_removeDeletesAllMatchingElements()
    {
        let array = UUThreadSafeArray<Int>()
        array.append(1)
        array.append(2)
        array.append(1)

        array.remove(1)

        XCTAssertEqual(array.count, 1)
        XCTAssertFalse(array.contains(1))
        XCTAssertEqual(array[0], 2)
    }
}

final class UUThreadSafeDictionaryTests: XCTestCase
{
    func test_threadSafeDictionary_setGetAndRemove()
    {
        let dictionary = UUThreadSafeDictionary<String, Int>()

        dictionary["one"] = 1
        dictionary["two"] = 2

        XCTAssertEqual(dictionary.count, 2)
        XCTAssertEqual(dictionary["one"], 1)
        XCTAssertEqual(dictionary.removeValue(forKey: "one"), 1)
        XCTAssertNil(dictionary["one"])
        XCTAssertEqual(dictionary.count, 1)
    }

    func test_threadSafeDictionary_removeAllClearsValues()
    {
        let dictionary = UUThreadSafeDictionary<String, Int>()
        dictionary["one"] = 1
        dictionary["two"] = 2

        dictionary.removeAll()

        XCTAssertEqual(dictionary.count, 0)
        XCTAssertNil(dictionary["one"])
        XCTAssertNil(dictionary["two"])
    }
}

final class UUMutexWrapperTests: XCTestCase
{
    func test_synchronizedSupportsRecursiveLocking()
    {
        let mutex = UUMutexWrapper()

        let value = mutex.synchronized
        {
            mutex.synchronized
            {
                "nested"
            }
        }

        XCTAssertEqual(value, "nested")
    }
}
