//
//  UUSecurityTests.swift
//  UUSwiftCoreTests
//
//  Created by Ryan DeVore on 6/23/26.
//

#if os(iOS) || os(macOS)

import CryptoKit
import Security
import XCTest
@testable import UUSwiftCore

private let keychainIntegrationUnavailableMessage =
    "Keychain access requires a signed test host with keychain entitlements."

// MARK: - Configuration

final class UUSecurityConfigurationTests: XCTestCase
{
    func test_keyStore_requireSecureEnclave_matchesHardwareAvailability() async
    {
        XCTAssertEqual(
            UUSecurity.keyStore.requireSecureEnclave,
            SecureEnclave.isAvailable)
    }

    func test_keyStore_hasExpectedDefaultConfiguration() async
    {
        XCTAssertEqual(UUSecurity.keyStore.keySizeBits, 256)
        XCTAssertEqual(UUSecurity.keyStore.algorithm, KeyStoreTestSupport.defaultAlgorithm())
        XCTAssertEqual(UUSecurity.keyStore.accessLevel, .afterFirstUnlockThisDeviceOnly)
        XCTAssertNil(UUSecurity.keyStore.accessGroup)
    }

    func test_keyStore_usesDeviceKeyStoreImplementation() async
    {
        XCTAssertTrue(UUSecurity.keyStore is UUDeviceKeyStore)
    }

    func test_crypto_isBoundToDefaultKeyAlias() async
    {
        XCTAssertEqual(UUSecurity.defaultCryptoKeyAlias, "com.silverpine.uu.core.security.UUCrypto")
    }
}

// MARK: - Shared key store

final class UUSecuritySharedKeyStoreTests: XCTestCase
{
    func test_crypto_roundTrip_usesSameKeyStoreAsStaticKeyStore() async throws
    {
        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        let companionCrypto = UUCrypto(
            keyAlias: UUSecurity.defaultCryptoKeyAlias,
            keyStore: UUSecurity.keyStore)
        let plaintext = Data("security-shared-keystore".utf8)

        let encrypted = try await UUSecurity.crypto.encrypt(value: plaintext).get()
        let decrypted = try await companionCrypto.decrypt(value: encrypted).get()

        XCTAssertEqual(decrypted, plaintext)
    }
}

// MARK: - Keychain integration (Simulator and macOS)

final class UUSecurityIntegrationTests: XCTestCase
{
    private var featureAlias: String!

    override func setUp() async throws
    {
        try await super.setUp()

        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        featureAlias = KeyStoreTestSupport.makeAlias(namespace: KeyStoreTestSupport.makeNamespace())
    }

    override func tearDown() async throws
    {
        if let featureAlias
        {
            _ = await UUSecurity.keyStore.deleteKey(alias: featureAlias)
            KeyStoreTestSupport.deleteKey(alias: featureAlias)
        }

        try await super.tearDown()
    }

    func test_crypto_encryptAndDecrypt_roundTrip_succeeds() async throws
    {
        let plaintext = Data("security-integration-round-trip".utf8)
        let encrypted = try await UUSecurity.crypto.encrypt(value: plaintext).get()
        let decrypted = try await UUSecurity.crypto.decrypt(value: encrypted).get()

        XCTAssertNotNil(encrypted)
        XCTAssertEqual(decrypted, plaintext)
    }

    func test_crypto_nullAndEmptyInputs_passthrough() async throws
    {
        let encryptedNil = try await UUSecurity.crypto.encrypt(value: nil).get()
        let decryptedNil = try await UUSecurity.crypto.decrypt(value: nil).get()
        XCTAssertNil(encryptedNil)
        XCTAssertNil(decryptedNil)

        let empty = Data()
        let encryptedEmpty = try await UUSecurity.crypto.encrypt(value: empty).get()
        let decryptedEmpty = try await UUSecurity.crypto.decrypt(value: empty).get()
        XCTAssertEqual(encryptedEmpty, empty)
        XCTAssertEqual(decryptedEmpty, empty)
    }

    func test_keyStore_loadKey_succeedsForPerCallAlias() async throws
    {
        let featureCrypto = UUCrypto(keyAlias: featureAlias, keyStore: UUSecurity.keyStore)
        let plaintext = Data("security-feature-alias".utf8)

        let encrypted = try await featureCrypto.encrypt(value: plaintext).get()
        let decrypted = try await featureCrypto.decrypt(value: encrypted).get()

        XCTAssertEqual(decrypted, plaintext)
    }
}

#endif
