//
//  UUKeyStoreConnectedTests.swift
//  LibraryConnectedTests
//
//  Created by Ryan DeVore on 6/23/26.
//

#if os(iOS)

import CryptoKit
import Security
import XCTest
@testable import UUSwiftCore

/// Secure Enclave integration tests. Run on a physical iOS device with Secure Enclave hardware.
final class UUKeyStoreConnectedTests: XCTestCase
{
    private var tagPrefix: String!
    private var keyStore: UUKeyStore!

    override func setUp() async throws
    {
        try await super.setUp()

        guard SecureEnclave.isAvailable else
        {
            throw XCTSkip("Secure Enclave is not available. Run these tests on a physical iOS device.")
        }

        tagPrefix = KeyStoreTestSupport.makeTagPrefix()
        keyStore = UUKeyStore(
            tagPrefix: tagPrefix,
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
    }

    override func tearDown() async throws
    {
        if let keyStore
        {
            _ = await keyStore.deleteKey(alias: TestAliases.primary)
            _ = await keyStore.deleteKey(alias: TestAliases.secondary)
        }

        keyStore = nil
        try await super.tearDown()
    }

    func test_loadKey_createsSecureEnclaveBackedKey() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: TestAliases.primary).get()

        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(privateKey))
    }

    func test_loadKey_privateKeyIsNotExtractable() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: TestAliases.primary).get()

        XCTAssertTrue(KeyStoreTestSupport.isPrivateKeyExportBlocked(privateKey))
    }

    func test_loadKey_supportsDocumentedEciesAlgorithm() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: TestAliases.primary).get()

        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(
            privateKey,
            algorithm: KeyStoreTestSupport.defaultAlgorithm()))
    }

    func test_loadKey_eciesRoundTrip_succeeds() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: TestAliases.primary).get()
        let plaintext = Data("connected-secure-enclave".utf8)

        let decrypted = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: privateKey,
            plaintext: plaintext,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_loadKey_isIdempotentForSameAlias() async throws
    {
        let first = try await keyStore.loadKey(alias: TestAliases.primary).get()
        let second = try await keyStore.loadKey(alias: TestAliases.primary).get()

        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(first))
        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(second))
        let algorithm = KeyStoreTestSupport.defaultAlgorithm()
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(first, algorithm: algorithm))
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(second, algorithm: algorithm))
    }

    func test_deleteKey_allowsRecreate() async throws
    {
        let alias = TestAliases.primary
        let originalKey = try await keyStore.loadKey(alias: alias).get()
        let originalPlaintext = Data("original-connected".utf8)
        _ = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: originalKey,
            plaintext: originalPlaintext)

        let deleteError = await keyStore.deleteKey(alias: alias)
        XCTAssertNil(deleteError)

        let replacementKey = try await keyStore.loadKey(alias: alias).get()
        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(replacementKey))

        let replacementPlaintext = Data("replacement-connected".utf8)
        let decrypted = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: replacementKey,
            plaintext: replacementPlaintext)

        XCTAssertEqual(decrypted, replacementPlaintext)
    }

    func test_multipleAliases_storeIndependentSecureEnclaveKeys() async throws
    {
        let keyA = try await keyStore.loadKey(alias: TestAliases.primary).get()
        let keyB = try await keyStore.loadKey(alias: TestAliases.secondary).get()

        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(keyA))
        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(keyB))

        let plaintextA = Data("connected-alpha".utf8)
        let plaintextB = Data("connected-beta".utf8)

        XCTAssertEqual(
            try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyA, plaintext: plaintextA),
            plaintextA)
        XCTAssertEqual(
            try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyB, plaintext: plaintextB),
            plaintextB)
    }

    func test_keysAreScopedByTagPrefix() async throws
    {
        let alias = TestAliases.primary
        let otherPrefix = KeyStoreTestSupport.makeTagPrefix()
        let otherStore = UUKeyStore(
            tagPrefix: otherPrefix,
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        defer
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: otherPrefix, alias: alias)
        }

        _ = try await keyStore.loadKey(alias: alias).get()
        let otherKey = try await otherStore.loadKey(alias: alias).get()

        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(otherKey))
    }

    func test_invalidEntryRecovery_replacesKeychainKeyWithSecureEnclaveKey() async throws
    {
        let alias = KeyStoreTestSupport.makeAlias()
        let sharedPrefix = KeyStoreTestSupport.makeTagPrefix()
        let keychainStore = UUKeyStore(
            tagPrefix: sharedPrefix,
            requireSecureEnclave: false,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
        let secureStore = UUKeyStore(
            tagPrefix: sharedPrefix,
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        defer
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: sharedPrefix, alias: alias)
        }

        let keychainKey = try await keychainStore.loadKey(alias: alias).get()
        XCTAssertFalse(KeyStoreTestSupport.isSecureEnclaveBacked(keychainKey))

        let secureKey = try await secureStore.loadKey(alias: alias).get()
        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(secureKey))

        let plaintext = Data("invalid-entry-recovery".utf8)
        let decrypted = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: secureKey,
            plaintext: plaintext,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_concurrentLoadKeyFromSeparateStores_resolvesDuplicateItem() async throws
    {
        let sharedPrefix = KeyStoreTestSupport.makeTagPrefix()
        let alias = KeyStoreTestSupport.makeAlias()
        let storeA = UUKeyStore(
            tagPrefix: sharedPrefix,
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
        let storeB = UUKeyStore(
            tagPrefix: sharedPrefix,
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        defer
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: sharedPrefix, alias: alias)
        }

        async let loadA = storeA.loadKey(alias: alias)
        async let loadB = storeB.loadKey(alias: alias)

        let keyA = try await loadA.get()
        let keyB = try await loadB.get()

        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(keyA))
        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(keyB))

        let plaintext = Data("connected-duplicate-race".utf8)
        XCTAssertEqual(
            try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyA, plaintext: plaintext),
            plaintext)
        XCTAssertEqual(
            try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyB, plaintext: plaintext),
            plaintext)
    }
}

// MARK: - Test support

private enum TestAliases
{
    static let primary = "primary-key"
    static let secondary = "secondary-key"
}

#endif
