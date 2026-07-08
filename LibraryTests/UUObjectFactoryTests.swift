//
//  UUObjectFactoryTests.swift
//  UUSwiftCore
//

import XCTest
@testable import UUSwiftCore

private final class FactoryBackedObject: Equatable, UUObjectFactory, UUObjectMapping
{
    var id: String = ""
    var contextValue: String?

    init(id: String = "", contextValue: String? = nil)
    {
        self.id = id
        self.contextValue = contextValue
    }

    static func == (lhs: FactoryBackedObject, rhs: FactoryBackedObject) -> Bool
    {
        lhs.id == rhs.id && lhs.contextValue == rhs.contextValue
    }

    static func uuObjectFromDictionary(dictionary: [AnyHashable: Any], context: Any?) -> FactoryBackedObject?
    {
        guard let id = dictionary["id"] as? String else
        {
            return nil
        }

        let object = FactoryBackedObject(id: id)
        object.uuMapFromDictionary(dictionary: dictionary, context: context)
        return object
    }

    func uuMapFromDictionary(dictionary: [AnyHashable: Any], context: Any?)
    {
        id = dictionary["id"] as? String ?? id
        contextValue = context as? String
    }
}

final class UUObjectFactoryTests: XCTestCase
{
    func test_uuObjectFromDictionary_buildsObjectWhenRequiredFieldsExist()
    {
        let object = FactoryBackedObject.uuObjectFromDictionary(
            dictionary: ["id": "abc"],
            context: "ctx")

        XCTAssertEqual(object, FactoryBackedObject(id: "abc", contextValue: "ctx"))
    }

    func test_uuObjectFromDictionary_returnsNilWhenRequiredFieldsAreMissing()
    {
        XCTAssertNil(FactoryBackedObject.uuObjectFromDictionary(dictionary: [:], context: nil))
    }

    func test_uuMapFromDictionary_updatesExistingObject()
    {
        let object = FactoryBackedObject(id: "old")

        object.uuMapFromDictionary(dictionary: ["id": "new"], context: "ctx")

        XCTAssertEqual(object, FactoryBackedObject(id: "new", contextValue: "ctx"))
    }
}
