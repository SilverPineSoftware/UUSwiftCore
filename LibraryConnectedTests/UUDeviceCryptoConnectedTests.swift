//
//  UUDeviceCryptoConnectedTests.swift
//  LibraryConnectedTests
//
//  Created by Ryan DeVore on 6/23/26.
//

#if os(iOS)

import CryptoKit
import Security
import XCTest
@testable import UUSwiftCore

/// Secure Enclave integration tests for ``UUDeviceCrypto``. Run on a physical iOS device with Secure Enclave hardware.
final class UUDeviceCryptoConnectedTests: XCTestCase
{
    private var primaryAlias: String!
    private var secondaryAlias: String!
    private var keyStore: UUDeviceKeyStore!
    private var crypto: UUDeviceCrypto!

    override func setUp() async throws
    {
        try await super.setUp()

        guard SecureEnclave.isAvailable else
        {
            throw XCTSkip("Secure Enclave is not available. Run these tests on a physical iOS device.")
        }

        let namespace = KeyStoreTestSupport.makeNamespace()
        primaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "primary-key")
        secondaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "secondary-key")
        keyStore = UUDeviceKeyStore(
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
        crypto = UUDeviceCrypto(keyAlias: primaryAlias, keyStore: keyStore)
    }

    override func tearDown() async throws
    {
        if let keyStore
        {
            _ = await keyStore.deleteKey(alias: primaryAlias)
            _ = await keyStore.deleteKey(alias: secondaryAlias)
        }

        crypto = nil
        keyStore = nil
        try await super.tearDown()
    }

    func test_encryptAndDecrypt_roundTrip_succeeds() async throws
    {
        let plaintext = Data("connected-crypto-round-trip".utf8)
        let encrypted = try await crypto.encrypt(value: plaintext).get()
        let decrypted = try await crypto.decrypt(value: encrypted).get()

        XCTAssertNotNil(encrypted)
        XCTAssertFalse(encrypted!.isEmpty)
        XCTAssertEqual(decrypted, plaintext)
    }

    func test_encrypt_producesDifferentCiphertextForSamePlaintext() async throws
    {
        let plaintext = Data("connected-non-deterministic".utf8)
        let first = try await crypto.encrypt(value: plaintext).get()
        let second = try await crypto.encrypt(value: plaintext).get()

        XCTAssertNotEqual(first, second)

        let decryptedFirst = try await crypto.decrypt(value: first).get()
        let decryptedSecond = try await crypto.decrypt(value: second).get()
        XCTAssertEqual(decryptedFirst, plaintext)
        XCTAssertEqual(decryptedSecond, plaintext)
    }

    func test_multipleAliases_storeIndependentSecureEnclaveKeys() async throws
    {
        let plaintextA = Data("connected-crypto-alpha".utf8)
        let plaintextB = Data("connected-crypto-beta".utf8)

        let encryptedA = try await crypto.encrypt(value: plaintextA, keyAlias: primaryAlias).get()
        let encryptedB = try await crypto.encrypt(value: plaintextB, keyAlias: secondaryAlias).get()

        let decryptedA = try await crypto.decrypt(value: encryptedA, keyAlias: primaryAlias).get()
        let decryptedB = try await crypto.decrypt(value: encryptedB, keyAlias: secondaryAlias).get()
        XCTAssertEqual(decryptedA, plaintextA)
        XCTAssertEqual(decryptedB, plaintextB)

        let wrongKeyResult = await crypto.decrypt(value: encryptedA, keyAlias: secondaryAlias)
        guard case .failure(.decryptionFailed) = wrongKeyResult else
        {
            XCTFail("Expected .decryptionFailed, got \(wrongKeyResult)")
            return
        }
    }

    func test_sameAlias_isSharedAcrossCryptoInstances() async throws
    {
        let otherCrypto = UUDeviceCrypto(keyAlias: primaryAlias, keyStore: keyStore)
        let plaintext = Data("connected-shared-crypto".utf8)

        let encrypted = try await crypto.encrypt(value: plaintext).get()
        let decrypted = try await otherCrypto.decrypt(value: encrypted).get()

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_nullAndEmptyInputs_passthrough() async throws
    {
        let encryptedNil = try await crypto.encrypt(value: nil).get()
        let decryptedNil = try await crypto.decrypt(value: nil).get()
        XCTAssertNil(encryptedNil)
        XCTAssertNil(decryptedNil)

        let empty = Data()
        let encryptedEmpty = try await crypto.encrypt(value: empty).get()
        let decryptedEmpty = try await crypto.decrypt(value: empty).get()
        XCTAssertEqual(encryptedEmpty, empty)
        XCTAssertEqual(decryptedEmpty, empty)
    }
}

#endif
