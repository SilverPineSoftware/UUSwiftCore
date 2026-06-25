//
//  UUKeychainTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/16/26.
//
//  Tests for ``UUKeychain``, ``UUPlainKeychain``, and ``UUKeychainBase`` subclasses.
//

#if os(iOS) || os(macOS)

import Security
import XCTest
@testable import UUSwiftCore

// MARK: - Error mapping

final class UUKeychainErrorTests: XCTestCase
{
    func test_init_mapsKnownOSStatuses() async
    {
        XCTAssertEqual(UUKeychainError(errSecItemNotFound), .notFound)
        XCTAssertEqual(UUKeychainError(errSecDuplicateItem), .duplicateItem)
        XCTAssertEqual(UUKeychainError(errSecAuthFailed), .authFailed)
        XCTAssertEqual(UUKeychainError(errSecInteractionNotAllowed), .interactionNotAllowed)
        XCTAssertEqual(UUKeychainError(errSecMissingEntitlement), .missingEntitlement)
    }

    func test_init_mapsUnknownOSStatusToOsStatus() async
    {
        let status: OSStatus = -999
        XCTAssertEqual(UUKeychainError(status), .osStatus(status))
    }

    func test_status_returnsUnderlyingOSStatusForMappedErrors() async
    {
        XCTAssertEqual(UUKeychainError.notFound.status, errSecItemNotFound)
        XCTAssertEqual(UUKeychainError.duplicateItem.status, errSecDuplicateItem)
        XCTAssertEqual(UUKeychainError.authFailed.status, errSecAuthFailed)
        XCTAssertEqual(UUKeychainError.interactionNotAllowed.status, errSecInteractionNotAllowed)
        XCTAssertEqual(UUKeychainError.missingEntitlement.status, errSecMissingEntitlement)
        XCTAssertEqual(UUKeychainError.osStatus(-42).status, -42)
    }

    func test_status_isNilForValidationErrors() async
    {
        XCTAssertNil(UUKeychainError.unexpectedData.status)
        XCTAssertNil(UUKeychainError.emptyData.status)
        XCTAssertNil(UUKeychainError.invalidKey.status)
        XCTAssertNil(UUKeychainError.invalidStringEncoding.status)
        XCTAssertNil(UUKeychainError.transformFailed(underlying: nil).status)
    }

    func test_errorDescription_isNonEmptyForAllCases() async
    {
        let errors: [UUKeychainError] = [
            .notFound,
            .duplicateItem,
            .authFailed,
            .interactionNotAllowed,
            .missingEntitlement,
            .unexpectedData,
            .emptyData,
            .invalidKey,
            .invalidStringEncoding,
            .transformFailed(underlying: nil),
            .transformFailed(underlying: NSError(domain: "test", code: 1)),
            .osStatus(-1),
        ]

        for error in errors
        {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Missing description for \(error)")
        }
    }
}

// MARK: - Access levels

final class UUKeychainAccessLevelTests: XCTestCase
{
    func test_eachAccessLevel_mapsToSecurityConstant() async
    {
        XCTAssertTrue(UUKeychainAccessLevel.whenUnlocked.value === kSecAttrAccessibleWhenUnlocked)
        XCTAssertTrue(UUKeychainAccessLevel.afterFirstUnlock.value === kSecAttrAccessibleAfterFirstUnlock)
        XCTAssertTrue(UUKeychainAccessLevel.whenPasscodeSetThisDeviceOnly.value === kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
        XCTAssertTrue(UUKeychainAccessLevel.whenUnlockedThisDeviceOnly.value === kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        XCTAssertTrue(UUKeychainAccessLevel.afterFirstUnlockThisDeviceOnly.value === kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    }
}

// MARK: - Validation (all platforms)

final class UUKeychainValidationTests: XCTestCase
{
    private var keychain: UUPlainKeychain!

    override func setUp() async throws
    {
        try await super.setUp()
        keychain = UUPlainKeychain(serviceIdentifier: "com.uu.tests.keychain.validation.\(UUID().uuidString)")
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

    func test_readString_returnsInvalidKeyForEmptyKey() async
    {
        let result = await keychain.readString(key: "")

        guard case .failure(.invalidKey) = result else
        {
            XCTFail("Expected .invalidKey, got \(result)")
            return
        }
    }

    func test_writeString_returnsInvalidKeyForEmptyKey() async
    {
        let error = await keychain.writeString(
            key: "",
            accessLevel: .whenUnlocked,
            string: "secret")

        XCTAssertEqual(error, .invalidKey)
    }

    func test_writeString_returnsInvalidStringEncodingForNonASCIIWithASCIIEncoding() async
    {
        let error = await keychain.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "über",
            encoding: .ascii)

        XCTAssertEqual(error, .invalidStringEncoding)
    }
}

// MARK: - Mock protocol tests

final class UUKeychainMockTests: XCTestCase
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

    func test_mockKeychain_writeOverwritesExistingValue() async
    {
        let mock = MockKeychain()

        let firstWriteError = await mock.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("original".utf8))
        XCTAssertNil(firstWriteError)

        let secondWriteError = await mock.write(
            key: TestKeys.primary,
            accessLevel: .afterFirstUnlock,
            data: Data("updated".utf8))
        XCTAssertNil(secondWriteError)

        let result = await mock.read(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), Data("updated".utf8))
    }

    func test_mockKeychain_clear_isIdempotentWhenItemIsMissing() async
    {
        let mock = MockKeychain()
        let clearError = await mock.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)
    }

    func test_mockKeychain_itemsAreScopedByServiceIdentifier() async
    {
        let serviceA = "mock.service.a"
        let serviceB = "mock.service.b"
        let keychainA = MockKeychain(serviceIdentifier: serviceA)
        let keychainB = MockKeychain(serviceIdentifier: serviceB)

        let writeError = await keychainA.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("scoped".utf8))
        XCTAssertNil(writeError)

        let result = await keychainB.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound across services, got \(result)")
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

    func test_mockKeychain_writeString_overwritesExistingValue() async
    {
        let mock = MockKeychain()

        let firstWriteError = await mock.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "first")
        XCTAssertNil(firstWriteError)

        let secondWriteError = await mock.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "second")
        XCTAssertNil(secondWriteError)

        let result = await mock.readString(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), "second")
    }

    func test_mockKeychain_readString_roundTripsWithCustomEncoding() async
    {
        let mock = MockKeychain()
        let value = "héllo"

        let writeError = await mock.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: value,
            encoding: .utf16)
        XCTAssertNil(writeError)

        let result = await mock.readString(key: TestKeys.primary, encoding: .utf16)
        XCTAssertEqual(try? result.get(), value)
    }

    func test_mockKeychain_readString_returnsNotFoundForMissingKey() async
    {
        let mock = MockKeychain()
        let result = await mock.readString(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound, got \(result)")
            return
        }
    }

    func test_mockKeychain_readString_returnsInvalidKeyForEmptyKey() async
    {
        let mock = MockKeychain()
        let result = await mock.readString(key: "")

        guard case .failure(.invalidKey) = result else
        {
            XCTFail("Expected .invalidKey, got \(result)")
            return
        }
    }

    func test_mockKeychain_readString_returnsUnexpectedDataForInvalidUTF8() async
    {
        let mock = MockKeychain()

        let writeError = await mock.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data([0xFF, 0xFE, 0xFD]))
        XCTAssertNil(writeError)

        let result = await mock.readString(key: TestKeys.primary)

        guard case .failure(.unexpectedData) = result else
        {
            XCTFail("Expected .unexpectedData, got \(result)")
            return
        }
    }

    func test_mockKeychain_writeString_returnsInvalidStringEncoding() async
    {
        let mock = MockKeychain()

        let error = await mock.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "über",
            encoding: .ascii)

        XCTAssertEqual(error, .invalidStringEncoding)
    }

    func test_mockKeychain_itemsAreVisibleAcrossInstancesWithSameAccessGroup() async
    {
        let group = "group.shared"
        let service = "mock.service.shared"
        let writer = MockKeychain(serviceIdentifier: service, accessGroup: group)
        let reader = MockKeychain(serviceIdentifier: service, accessGroup: group)

        let writeError = await writer.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("shared-secret".utf8))
        XCTAssertNil(writeError)

        let result = await reader.read(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), Data("shared-secret".utf8))
    }

    func test_mockKeychain_itemsAreIsolatedByAccessGroup() async
    {
        let service = "mock.service.isolated"
        let grouped = MockKeychain(serviceIdentifier: service, accessGroup: "group.a")
        let otherGroup = MockKeychain(serviceIdentifier: service, accessGroup: "group.b")

        let writeError = await grouped.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("grouped".utf8))
        XCTAssertNil(writeError)

        let result = await otherGroup.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound across access groups, got \(result)")
            return
        }
    }
}

// MARK: - Test support

private enum TestKeys
{
    static let primary = "primary-key"
    static let secondary = "secondary-key"
}

private actor MockKeychainStore
{
    static let shared = MockKeychainStore()

    private var storage: [String: Data] = [:]

    func read(key: String) -> Data?
    {
        storage[key]
    }

    func write(key: String, data: Data)
    {
        storage[key] = data
    }

    func clear(key: String)
    {
        storage.removeValue(forKey: key)
    }
}

private actor MockKeychain: UUKeychain
{
    let serviceIdentifier: String
    let accessGroup: String?

    init(serviceIdentifier: String = "mock.service", accessGroup: String? = nil)
    {
        self.serviceIdentifier = serviceIdentifier
        self.accessGroup = accessGroup
    }

    private func storageKey(_ key: String) -> String
    {
        "\(accessGroup ?? "<default>")|\(serviceIdentifier)|\(key)"
    }

    func read(key: String) async -> Result<Data, UUKeychainError>
    {
        guard !key.isEmpty else
        {
            return .failure(.invalidKey)
        }

        guard let data = await MockKeychainStore.shared.read(key: storageKey(key)) else
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

        await MockKeychainStore.shared.write(key: storageKey(key), data: data)
        return nil
    }

    func clear(key: String) async -> UUKeychainError?
    {
        guard !key.isEmpty else
        {
            return .invalidKey
        }

        await MockKeychainStore.shared.clear(key: storageKey(key))
        return nil
    }
}

#endif
