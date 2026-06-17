//
//  UUKeychainTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/16/26.
//

#if os(iOS) || os(macOS)

import XCTest
@testable import UUSwiftCore

// MARK: - Validation (all platforms)

final class UUKeychainValidationTests: XCTestCase
{
    private var keychain: UUKeychain!

    override func setUp() async throws
    {
        try await super.setUp()
        keychain = UUKeychain(serviceIdentifier: "com.uu.tests.keychain.validation.\(UUID().uuidString)")
    }

    func test_read_returnsInvalidKeyForEmptyKey() async
    {
        let result = await keychain.read(key: "")

        guard case .failure(.invalidKey) = result else
        {
            XCTFail("Expected .invalidKey, got \(result)")
            return
        }
    }

    func test_write_returnsEmptyDataForEmptyPayload() async
    {
        let error = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data())

        XCTAssertEqual(error, .emptyData)
    }

    func test_write_returnsInvalidKeyForEmptyKey() async
    {
        let error = await keychain.write(
            key: "",
            accessLevel: .whenUnlocked,
            data: Data("secret".utf8))

        XCTAssertEqual(error, .invalidKey)
    }

    func test_clear_returnsInvalidKeyForEmptyKey() async
    {
        let clearError = await keychain.clear(key: "")
        XCTAssertEqual(clearError, .invalidKey)
    }

    func test_writeString_returnsEmptyDataForEmptyString() async
    {
        let error = await keychain.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "")

        XCTAssertEqual(error, .emptyData)
    }
}

// MARK: - Mock protocol tests

final class UUKeychainProtocolTests: XCTestCase
{
    func test_mockKeychain_readWriteClear() async
    {
        let mock = MockKeychain()

        let writeError = await mock.write(
            key: "token",
            accessLevel: .whenUnlocked,
            data: Data("abc".utf8))
        XCTAssertNil(writeError)

        let read = await mock.read(key: "token")
        XCTAssertEqual(try? read.get(), Data("abc".utf8))

        let clearError = await mock.clear(key: "token")
        XCTAssertNil(clearError)

        let missing = await mock.read(key: "token")
        guard case .failure(.notFound) = missing else
        {
            XCTFail("Expected .notFound")
            return
        }
    }

    func test_mockKeychain_writeStringUsesProtocolExtension() async
    {
        let mock = MockKeychain()

        let writeError = await mock.writeString(
            key: "name",
            accessLevel: .whenUnlocked,
            string: "hello")
        XCTAssertNil(writeError)

        let result = await mock.readString(key: "name")
        XCTAssertEqual(try? result.get(), "hello")
    }
}

// MARK: - Test support

private enum TestKeys
{
    static let primary = "primary-key"
    static let secondary = "secondary-key"
}

private actor MockKeychain: UUKeychainProtocol
{
    let serviceIdentifier = "mock.service"
    let accessGroup: String? = nil

    private var storage: [String: Data] = [:]

    func read(key: String) async -> Result<Data, UUKeychainError>
    {
        guard !key.isEmpty else
        {
            return .failure(.invalidKey)
        }

        guard let data = storage[key] else
        {
            return .failure(.notFound)
        }

        return .success(data)
    }

    func write(key: String, accessLevel: UUKeychainAccessLevel, data: Data) async -> UUKeychainError?
    {
        guard !key.isEmpty else
        {
            return .invalidKey
        }

        guard !data.isEmpty else
        {
            return .emptyData
        }

        storage[key] = data
        return nil
    }

    func clear(key: String) async -> UUKeychainError?
    {
        guard !key.isEmpty else
        {
            return .invalidKey
        }

        storage.removeValue(forKey: key)
        return nil
    }
}

#endif
