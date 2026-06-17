//
//  UUKeychainTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/16/26.
//

#if os(iOS) || os(macOS)

import XCTest
@testable import UUSwiftCore

// MARK: - Keychain integration (requires test host on iOS)

final class UUKeychainIntegrationTests: XCTestCase
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
        guard let accessGroup = KeychainTestSupport.entitledAccessGroup() else
        {
            throw XCTSkip("Shared keychain access group entitlement is not configured on the test host.")
        }

        let groupedKeychain = UUKeychain(
            serviceIdentifier: serviceIdentifier,
            accessGroup: accessGroup)
        let ungroupedKeychain = UUKeychain(serviceIdentifier: serviceIdentifier)

        let writeError = await groupedKeychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("group-only".utf8))
        XCTAssertNil(writeError)

        let result = await ungroupedKeychain.read(key: TestKeys.primary)

        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected ungrouped keychain to miss grouped item, got \(result)")
            return
        }

        let clearError = await groupedKeychain.clear(key: TestKeys.primary)
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
