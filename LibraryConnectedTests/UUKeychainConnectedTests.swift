//
//  UUKeychainConnectedTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/16/26.
//

#if os(iOS) || os(macOS)

import XCTest
@testable import UUSwiftCore

// MARK: - Keychain integration (requires test host on iOS)

final class UUKeychainConnectedTests: XCTestCase
{
    private var serviceIdentifier: String!
    private var keychain: UUKeychain!

    override func setUp() async throws
    {
        try await super.setUp()
        serviceIdentifier = "com.uu.tests.keychain.\(UUID().uuidString)"
        keychain = UUKeychain(serviceIdentifier: serviceIdentifier)
    }

    override func tearDown() async throws
    {
        _ = await keychain.clear(key: TestKeys.primary)
        _ = await keychain.clear(key: TestKeys.secondary)
        keychain = nil
        try await super.tearDown()
    }

    func test_read_returnsNotFoundForMissingKey() async
    {
        let result = await keychain.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound, got \(result)")
            return
        }
    }

    func test_writeAndRead_roundTripsData() async
    {
        let payload = Data("round-trip-secret".utf8)

        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: payload)
        XCTAssertNil(writeError)

        let result = await keychain.read(key: TestKeys.primary)

        XCTAssertEqual(try? result.get(), payload)
    }

    func test_write_overwritesExistingValue() async
    {
        let original = Data("original".utf8)
        let updated = Data("updated-value".utf8)

        let firstWriteError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: original)
        XCTAssertNil(firstWriteError)

        let secondWriteError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .afterFirstUnlock,
            data: updated)
        XCTAssertNil(secondWriteError)

        let result = await keychain.read(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), updated)
    }

    func test_writeString_overwritesExistingValue() async
    {
        let firstWriteError = await keychain.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "first-value")
        XCTAssertNil(firstWriteError)

        let secondWriteError = await keychain.writeString(
            key: TestKeys.primary,
            accessLevel: .afterFirstUnlock,
            string: "second-value")
        XCTAssertNil(secondWriteError)

        let result = await keychain.readString(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), "second-value")
    }

    func test_write_eachAccessLevel_roundTripsValue() async
    {
        let payload = Data("access-level-payload".utf8)
        let levels: [UUKeychainAccessLevel] = [
            .whenUnlocked,
            .afterFirstUnlock,
            .whenPasscodeSetThisDeviceOnly,
            .whenUnlockedThisDeviceOnly,
            .afterFirstUnlockThisDeviceOnly,
        ]

        for level in levels
        {
            let key = "access-level-\(level)"

            let writeError = await keychain.write(
                key: key,
                accessLevel: level,
                data: payload)

            if level == .whenPasscodeSetThisDeviceOnly, writeError != nil
            {
                continue
            }

            XCTAssertNil(writeError, "Write failed for \(level): \(String(describing: writeError))")

            let result = await keychain.read(key: key)
            XCTAssertEqual(try? result.get(), payload, "Read failed for \(level)")

            let updateError = await keychain.write(
                key: key,
                accessLevel: level,
                data: Data("updated-\(level)".utf8))

            if level == .whenPasscodeSetThisDeviceOnly, updateError != nil
            {
                continue
            }

            XCTAssertNil(updateError, "Update failed for \(level): \(String(describing: updateError))")

            let updated = await keychain.read(key: key)
            XCTAssertEqual(try? updated.get(), Data("updated-\(level)".utf8), "Updated read failed for \(level)")

            let clearError = await keychain.clear(key: key)
            XCTAssertNil(clearError)
        }
    }

    func test_multipleKeys_storeIndependently() async
    {
        let dataA = Data("alpha".utf8)
        let dataB = Data("beta".utf8)

        let writeAError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: dataA)
        XCTAssertNil(writeAError)

        let writeBError = await keychain.write(
            key: TestKeys.secondary,
            accessLevel: .whenUnlocked,
            data: dataB)
        XCTAssertNil(writeBError)

        let resultA = await keychain.read(key: TestKeys.primary)
        let resultB = await keychain.read(key: TestKeys.secondary)

        XCTAssertEqual(try? resultA.get(), dataA)
        XCTAssertEqual(try? resultB.get(), dataB)
    }

    func test_clear_removesStoredItem() async
    {
        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("to-delete".utf8))
        XCTAssertNil(writeError)

        let clearError = await keychain.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)

        let result = await keychain.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound after clear, got \(result)")
            return
        }
    }

    func test_clear_isIdempotentWhenItemIsMissing() async
    {
        let clearError = await keychain.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)
    }

    func test_readString_roundTripsUtf8() async
    {
        let value = "client-secret-123"

        let writeError = await keychain.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: value)
        XCTAssertNil(writeError)

        let result = await keychain.readString(key: TestKeys.primary)

        XCTAssertEqual(try? result.get(), value)
    }

    func test_readString_returnsUnexpectedDataForInvalidUTF8() async
    {
        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data([0xFF, 0xFE, 0xFD]))
        XCTAssertNil(writeError)

        let result = await keychain.readString(key: TestKeys.primary)

        guard case .failure(.unexpectedData) = result else
        {
            XCTFail("Expected .unexpectedData, got \(result)")
            return
        }
    }

    func test_readString_returnsNotFoundAfterClear() async
    {
        let writeError = await keychain.writeString(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            string: "temporary")
        XCTAssertNil(writeError)

        let clearError = await keychain.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)

        let result = await keychain.readString(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound after clear, got \(result)")
            return
        }
    }

    func test_write_returnsMissingEntitlementForUnentitledAccessGroup() async
    {
        let unentitledKeychain = UUKeychain(
            serviceIdentifier: serviceIdentifier,
            accessGroup: "com.silverpine.uu.not.entitled.\(UUID().uuidString)")

        let error = await unentitledKeychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("secret".utf8))

        XCTAssertEqual(error, .missingEntitlement)
    }

    func test_itemsAreScopedByServiceIdentifier() async
    {
        let otherKeychain = UUKeychain(serviceIdentifier: "\(serviceIdentifier!).other")

        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("scoped".utf8))
        XCTAssertNil(writeError)

        let result = await otherKeychain.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected other service to miss item, got \(result)")
            return
        }

        let clearError = await otherKeychain.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)
    }

    func test_itemsAreVisibleAcrossInstancesWithSameAccessGroup() async throws
    {
        guard let accessGroup = KeychainTestSupport.entitledAccessGroup() else
        {
            throw XCTSkip("Shared keychain access group entitlement is not configured on the test host.")
        }

        let writer = UUKeychain(
            serviceIdentifier: serviceIdentifier,
            accessGroup: accessGroup)
        let reader = UUKeychain(
            serviceIdentifier: serviceIdentifier,
            accessGroup: accessGroup)

        let writeError = await writer.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("shared-via-group".utf8))
        XCTAssertNil(writeError)

        let result = await reader.read(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), Data("shared-via-group".utf8))

        let clearError = await reader.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)
    }

    func test_itemsAreIsolatedByAccessGroup() async throws
    {
        guard let sharedAccessGroup = KeychainTestSupport.entitledAccessGroup(),
              let defaultAccessGroup = KeychainTestSupport.defaultAccessGroup()
        else
        {
            throw XCTSkip("Shared keychain access group entitlement is not configured on the test host.")
        }

        XCTAssertNotEqual(sharedAccessGroup, defaultAccessGroup)

        let sharedKeychain = UUKeychain(
            serviceIdentifier: serviceIdentifier,
            accessGroup: sharedAccessGroup)
        let defaultKeychain = UUKeychain(
            serviceIdentifier: serviceIdentifier,
            accessGroup: defaultAccessGroup)

        let writeError = await sharedKeychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("group-only".utf8))
        XCTAssertNil(writeError)

        let result = await defaultKeychain.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected default access group to miss shared-group item, got \(result)")
            return
        }

        let clearError = await sharedKeychain.clear(key: TestKeys.primary)
        XCTAssertNil(clearError)
    }
}

// MARK: - Test support

private enum TestKeys
{
    static let primary = "primary-key"
    static let secondary = "secondary-key"
}

#endif
