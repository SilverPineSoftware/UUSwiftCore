//
//  UUEncryptedKeychainConnectedTests.swift
//  LibraryConnectedTests
//
//  Created by Ryan DeVore on 6/23/26.
//

#if os(iOS)

import CryptoKit
import Security
import XCTest
@testable import UUSwiftCore

/// Secure Enclave and Keychain integration tests for ``UUEncryptedKeychain``.
/// Run on a physical iOS device with Secure Enclave hardware and keychain entitlements.
final class UUEncryptedKeychainConnectedTests: XCTestCase
{
    private var namespace: String!
    private var serviceIdentifier: String!
    private var primaryKey: String!
    private var secondaryKey: String!
    private var keyStore: UUDeviceKeyStore!
    private var keychain: UUEncryptedKeychain!
    private var rawKeychain: UUPlainKeychain!

    override func setUp() async throws
    {
        try await super.setUp()

        guard SecureEnclave.isAvailable else
        {
            throw XCTSkip("Secure Enclave is not available. Run these tests on a physical iOS device.")
        }

        namespace = KeyStoreTestSupport.makeNamespace()
        serviceIdentifier = KeyStoreTestSupport.qualifiedAlias(
            namespace: namespace,
            name: "encrypted-keychain-service")
        primaryKey = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "primary-key")
        secondaryKey = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "secondary-key")
        keyStore = UUDeviceKeyStore(
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
        keychain = UUEncryptedKeychain(
            serviceIdentifier: serviceIdentifier,
            crypto: UUCrypto(keyAlias: primaryKey, keyStore: keyStore))
        rawKeychain = UUPlainKeychain(serviceIdentifier: serviceIdentifier)
    }

    override func tearDown() async throws
    {
        if let keychain
        {
            _ = await keychain.clear(key: primaryKey)
            _ = await keychain.clear(key: secondaryKey)
        }

        if let keyStore
        {
            _ = await keyStore.deleteKey(alias: primaryKey)
            _ = await keyStore.deleteKey(alias: secondaryKey)
            KeyStoreTestSupport.deleteKey(alias: primaryKey)
            KeyStoreTestSupport.deleteKey(alias: secondaryKey)
        }

        rawKeychain = nil
        keychain = nil
        keyStore = nil
        try await super.tearDown()
    }

    func test_writeAndRead_roundTripsLogicalData() async throws
    {
        let payload = Data("connected-encrypted-keychain-round-trip".utf8)

        let writeError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payload)
        XCTAssertNil(writeError)

        let result = await keychain.read(key: primaryKey)
        XCTAssertEqual(try? result.get(), payload)
    }

    func test_write_persistsCiphertextInKeychain() async throws
    {
        let payload = Data("connected-ciphertext-at-rest".utf8)

        let writeError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payload)
        XCTAssertNil(writeError)

        let rawResult = await rawKeychain.read(key: primaryKey)
        let rawData = try XCTUnwrap(try? rawResult.get())
        XCTAssertNotEqual(rawData, payload)
        XCTAssertFalse(rawData.isEmpty)
    }

    func test_write_producesDifferentCiphertextForSamePlaintext() async throws
    {
        let payload = Data("connected-non-deterministic-keychain".utf8)

        let firstWriteError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payload)
        XCTAssertNil(firstWriteError)

        let firstRawResult = await rawKeychain.read(key: primaryKey)
        let firstRaw = try XCTUnwrap(try? firstRawResult.get())

        let secondWriteError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payload)
        XCTAssertNil(secondWriteError)

        let secondRawResult = await rawKeychain.read(key: primaryKey)
        let secondRaw = try XCTUnwrap(try? secondRawResult.get())
        XCTAssertNotEqual(firstRaw, secondRaw)

        let result = await keychain.read(key: primaryKey)
        XCTAssertEqual(try? result.get(), payload)
    }

    func test_multipleKeys_storeIndependentSecureEnclaveEncryptedValues() async throws
    {
        let payloadA = Data("connected-encrypted-alpha".utf8)
        let payloadB = Data("connected-encrypted-beta".utf8)

        let writeErrorA = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payloadA)
        let writeErrorB = await keychain.write(
            key: secondaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payloadB)
        XCTAssertNil(writeErrorA)
        XCTAssertNil(writeErrorB)

        let readA = try? await keychain.read(key: primaryKey).get()
        let readB = try? await keychain.read(key: secondaryKey).get()
        XCTAssertEqual(readA, payloadA)
        XCTAssertEqual(readB, payloadB)

        let rawAResult = await rawKeychain.read(key: primaryKey)
        let rawBResult = await rawKeychain.read(key: secondaryKey)
        let rawA = try XCTUnwrap(try? rawAResult.get())
        let rawB = try XCTUnwrap(try? rawBResult.get())
        XCTAssertNotEqual(rawA, rawB)
        XCTAssertNotEqual(rawA, payloadA)
        XCTAssertNotEqual(rawB, payloadB)
    }

    func test_keyStore_usesSecureEnclaveForEachKeychainKey() async throws
    {
        let writeError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: Data("secure-enclave-backing".utf8))
        XCTAssertNil(writeError)

        let privateKey = try await keyStore.loadKey(alias: primaryKey).get()
        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(privateKey))
        XCTAssertTrue(KeyStoreTestSupport.isPrivateKeyExportBlocked(privateKey))
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(
            privateKey,
            algorithm: KeyStoreTestSupport.defaultAlgorithm()))
    }

    func test_readString_roundTripsUtf8() async throws
    {
        let value = "connected-client-secret-42"

        let writeError = await keychain.writeString(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            string: value)
        XCTAssertNil(writeError)

        let result = await keychain.readString(key: primaryKey)
        XCTAssertEqual(try? result.get(), value)
    }

    func test_clear_removesStoredItem() async throws
    {
        let writeError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: Data("to-delete".utf8))
        XCTAssertNil(writeError)

        let clearError = await keychain.clear(key: primaryKey)
        XCTAssertNil(clearError)

        let result = await keychain.read(key: primaryKey)
        guard case .failure(.notFound) = result else
        {
            XCTFail("Expected .notFound after clear, got \(result)")
            return
        }
    }

    func test_write_overwritesExistingValue() async throws
    {
        let original = Data("original-connected".utf8)
        let updated = Data("updated-connected-value".utf8)

        let firstWriteError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: original)
        let secondWriteError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: updated)
        XCTAssertNil(firstWriteError)
        XCTAssertNil(secondWriteError)

        let result = await keychain.read(key: primaryKey)
        XCTAssertEqual(try? result.get(), updated)
    }

    func test_sameService_isSharedAcrossEncryptedKeychainInstances() async throws
    {
        let otherKeychain = UUEncryptedKeychain(
            serviceIdentifier: serviceIdentifier,
            crypto: UUCrypto(keyAlias: primaryKey, keyStore: keyStore))
        let payload = Data("connected-shared-encrypted-keychain".utf8)

        let writeError = await keychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payload)
        XCTAssertNil(writeError)

        let result = await otherKeychain.read(key: primaryKey)
        XCTAssertEqual(try? result.get(), payload)
    }

    func test_read_returnsTransformFailedForPlaintextStoredInKeychain() async throws
    {
        let payload = Data("tamper-detection".utf8)

        let writeError = await rawKeychain.write(
            key: primaryKey,
            accessLevel: .afterFirstUnlockThisDeviceOnly,
            data: payload)
        XCTAssertNil(writeError)

        let result = await keychain.read(key: primaryKey)
        guard case .failure(.transformFailed) = result else
        {
            XCTFail("Expected .transformFailed for unencrypted keychain bytes, got \(result)")
            return
        }
    }
}

#endif
