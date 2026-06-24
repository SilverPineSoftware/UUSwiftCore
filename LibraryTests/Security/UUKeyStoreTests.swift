//
//  UUKeyStoreTests.swift
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

// MARK: - Error mapping

final class UUKeyStoreErrorTests: XCTestCase
{
    func test_init_mapsKnownOSStatuses() async
    {
        XCTAssertEqual(UUKeyStoreError(errSecItemNotFound), .notFound)
        XCTAssertEqual(UUKeyStoreError(errSecDuplicateItem), .duplicateItem)
        XCTAssertEqual(UUKeyStoreError(errSecAuthFailed), .authFailed)
        XCTAssertEqual(UUKeyStoreError(errSecInteractionNotAllowed), .interactionNotAllowed)
        XCTAssertEqual(UUKeyStoreError(errSecMissingEntitlement), .missingEntitlement)
    }

    func test_init_mapsUnknownOSStatusToOsStatus() async
    {
        let status: OSStatus = -999
        XCTAssertEqual(UUKeyStoreError(status), .osStatus(status))
    }

    func test_errorDescription_isNonEmptyForAllCases() async
    {
        let errors: [UUKeyStoreError] = [
            .invalidAlias,
            .notFound,
            .invalidEntry,
            .keySizeNotSupported(384),
            .keyGenerationFailed(nil),
            .accessControlFailed(nil),
            .keyAlgorithmUnsupported,
            .secureEnclaveUnavailable,
            .duplicateItem,
            .authFailed,
            .interactionNotAllowed,
            .missingEntitlement,
            .osStatus(-1),
        ]

        for error in errors
        {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Missing description for \(error)")
        }
    }
}

// MARK: - Validation

final class UUKeyStoreValidationTests: XCTestCase
{
    private var keyStore: UUKeyStore!
    private var tagPrefix: String!

    override func setUp() async throws
    {
        try await super.setUp()
        tagPrefix = KeyStoreTestSupport.makeTagPrefix()
        keyStore = UUKeyStore(
            tagPrefix: tagPrefix,
            requireSecureEnclave: false)
    }

    override func tearDown() async throws
    {
        if let tagPrefix
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: tagPrefix, alias: TestAliases.primary)
            KeyStoreTestSupport.deleteKey(tagPrefix: tagPrefix, alias: TestAliases.secondary)
        }

        keyStore = nil
        try await super.tearDown()
    }

    func test_loadKey_returnsInvalidAliasForEmptyAlias() async
    {
        let result = await keyStore.loadKey(alias: "")

        guard case .failure(.invalidAlias) = result else
        {
            XCTFail("Expected .invalidAlias, got \(result)")
            return
        }
    }

    func test_deleteKey_returnsInvalidAliasForEmptyAlias() async
    {
        let error = await keyStore.deleteKey(alias: "")
        XCTAssertEqual(error, .invalidAlias)
    }

    func test_loadKey_secureEnclaveRequired_returnsUnavailableWhenSecureEnclaveMissing() async throws
    {
        guard !SecureEnclave.isAvailable else
        {
            throw XCTSkip("Secure Enclave is available; unavailable-path test applies to Simulator and legacy Mac.")
        }

        let secureStore = UUKeyStore(
            tagPrefix: KeyStoreTestSupport.makeTagPrefix(),
            requireSecureEnclave: true)
        let alias = KeyStoreTestSupport.makeAlias()

        let result = await secureStore.loadKey(alias: alias)

        guard case .failure(.secureEnclaveUnavailable) = result else
        {
            XCTFail("Expected .secureEnclaveUnavailable, got \(result)")
            return
        }
    }

    func test_loadKey_secureEnclaveRequired_returnsKeySizeNotSupportedForNon256BitKeys() async
    {
        let secureStore = UUKeyStore(
            tagPrefix: KeyStoreTestSupport.makeTagPrefix(),
            keySizeBits: 384,
            requireSecureEnclave: true)
        let alias = KeyStoreTestSupport.makeAlias()

        let result = await secureStore.loadKey(alias: alias)

        guard case .failure(.keySizeNotSupported(384)) = result else
        {
            XCTFail("Expected .keySizeNotSupported(384), got \(result)")
            return
        }
    }
}

// MARK: - Keychain integration (Simulator and macOS)

final class UUKeyStoreIntegrationTests: XCTestCase
{
    private var tagPrefix: String!
    private var keyStore: UUKeyStore!

    override func setUp() async throws
    {
        try await super.setUp()

        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        tagPrefix = KeyStoreTestSupport.makeTagPrefix()
        keyStore = UUKeyStore(
            tagPrefix: tagPrefix,
            requireSecureEnclave: false,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
    }

    override func tearDown() async throws
    {
        if let tagPrefix
        {
            _ = await keyStore?.deleteKey(alias: TestAliases.primary)
            _ = await keyStore?.deleteKey(alias: TestAliases.secondary)
            KeyStoreTestSupport.deleteKey(tagPrefix: tagPrefix, alias: TestAliases.primary)
            KeyStoreTestSupport.deleteKey(tagPrefix: tagPrefix, alias: TestAliases.secondary)
        }

        keyStore = nil
        try await super.tearDown()
    }

    func test_loadKey_createsAndReturnsPrivateKey() async throws
    {
        let alias = TestAliases.primary
        let result = await keyStore.loadKey(alias: alias)

        let privateKey = try XCTUnwrap(result.get())
        XCTAssertNotNil(SecKeyCopyPublicKey(privateKey))
        XCTAssertFalse(KeyStoreTestSupport.isSecureEnclaveBacked(privateKey))
    }

    func test_loadKey_isIdempotentForSameAlias() async throws
    {
        let alias = TestAliases.primary

        let first = try await keyStore.loadKey(alias: alias).get()
        let second = try await keyStore.loadKey(alias: alias).get()

        let algorithm = KeyStoreTestSupport.defaultAlgorithm()
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(first, algorithm: algorithm))
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(second, algorithm: algorithm))
    }

    func test_loadKey_supportsConfiguredEciesAlgorithm() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: TestAliases.primary).get()

        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(
            privateKey,
            algorithm: KeyStoreTestSupport.defaultAlgorithm()))
    }

    func test_loadKey_eciesRoundTrip_succeeds() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: TestAliases.primary).get()
        let plaintext = Data("keystore-round-trip".utf8)

        let decrypted = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: privateKey,
            plaintext: plaintext,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_deleteKey_removesStoredKey() async throws
    {
        let alias = TestAliases.primary
        _ = try await keyStore.loadKey(alias: alias).get()

        let deleteError = await keyStore.deleteKey(alias: alias)
        XCTAssertNil(deleteError)

        let reload = await keyStore.loadKey(alias: alias)
        XCTAssertNotNil(try? reload.get())
    }

    func test_deleteKey_isIdempotentWhenKeyIsMissing() async
    {
        let deleteError = await keyStore.deleteKey(alias: TestAliases.primary)
        XCTAssertNil(deleteError)
    }

    func test_keysAreScopedByTagPrefix() async throws
    {
        let alias = TestAliases.primary
        let otherPrefix = KeyStoreTestSupport.makeTagPrefix()
        let otherStore = UUKeyStore(tagPrefix: otherPrefix, requireSecureEnclave: false)

        defer
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: otherPrefix, alias: alias)
        }

        _ = try await keyStore.loadKey(alias: alias).get()

        let otherResult = await otherStore.loadKey(alias: alias)
        let otherKey = try XCTUnwrap(otherResult.get())

        XCTAssertFalse(KeyStoreTestSupport.isSecureEnclaveBacked(otherKey))
    }

    func test_multipleAliases_storeIndependently() async throws
    {
        let keyA = try await keyStore.loadKey(alias: TestAliases.primary).get()
        let keyB = try await keyStore.loadKey(alias: TestAliases.secondary).get()

        let plaintextA = Data("alpha".utf8)
        let plaintextB = Data("beta".utf8)

        let decryptedA = try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyA, plaintext: plaintextA)
        let decryptedB = try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyB, plaintext: plaintextB)

        XCTAssertEqual(decryptedA, plaintextA)
        XCTAssertEqual(decryptedB, plaintextB)
    }

    func test_concurrentLoadKeyFromSeparateStores_resolvesDuplicateItem() async throws
    {
        let sharedPrefix = KeyStoreTestSupport.makeTagPrefix()
        let alias = KeyStoreTestSupport.makeAlias()
        let storeA = UUKeyStore(tagPrefix: sharedPrefix, requireSecureEnclave: false)
        let storeB = UUKeyStore(tagPrefix: sharedPrefix, requireSecureEnclave: false)

        defer
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: sharedPrefix, alias: alias)
        }

        async let loadA = storeA.loadKey(alias: alias)
        async let loadB = storeB.loadKey(alias: alias)

        let resultA = await loadA
        let resultB = await loadB

        let keyA = try XCTUnwrap(resultA.get())
        let keyB = try XCTUnwrap(resultB.get())

        let plaintext = Data("duplicate-race".utf8)
        let decryptedA = try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyA, plaintext: plaintext)
        let decryptedB = try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyB, plaintext: plaintext)

        XCTAssertEqual(decryptedA, plaintext)
        XCTAssertEqual(decryptedB, plaintext)
    }

    func test_loadKey_afterDelete_producesNewWorkingKey() async throws
    {
        let alias = TestAliases.primary
        let originalKey = try await keyStore.loadKey(alias: alias).get()
        let originalPlaintext = Data("before-delete".utf8)

        guard let originalPublicKey = SecKeyCopyPublicKey(originalKey) else
        {
            XCTFail("Expected public key")
            return
        }

        var error: Unmanaged<CFError>?
        let algorithm = KeyStoreTestSupport.defaultAlgorithm()
        guard let originalCiphertext = SecKeyCreateEncryptedData(
            originalPublicKey,
            algorithm,
            originalPlaintext as CFData,
            &error) as Data?
        else
        {
            throw error?.takeRetainedValue() ?? KeyStoreTestError.encryptionFailed
        }

        _ = await keyStore.deleteKey(alias: alias)

        let replacementKey = try await keyStore.loadKey(alias: alias).get()
        let replacementPlaintext = Data("after-delete".utf8)
        let replacementDecrypted = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: replacementKey,
            plaintext: replacementPlaintext)

        XCTAssertEqual(replacementDecrypted, replacementPlaintext)

        let legacyDecrypt = SecKeyCreateDecryptedData(
            replacementKey,
            algorithm,
            originalCiphertext as CFData,
            &error)

        XCTAssertNil(legacyDecrypt, "Replacement key should not decrypt ciphertext from deleted key")
    }
}

// MARK: - Secure Enclave when hardware is available

final class UUKeyStoreSecureEnclaveIntegrationTests: XCTestCase
{
    private var tagPrefix: String?
    private var alias: String?

    override func tearDown() async throws
    {
        if let tagPrefix, let alias
        {
            KeyStoreTestSupport.deleteKey(tagPrefix: tagPrefix, alias: alias)
        }

        tagPrefix = nil
        alias = nil
        try await super.tearDown()
    }

    func test_loadKey_secureEnclaveRequired_createsHardwareBackedKeyWhenAvailable() async throws
    {
        guard SecureEnclave.isAvailable else
        {
            throw XCTSkip("Secure Enclave is not available on this host.")
        }

        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        tagPrefix = KeyStoreTestSupport.makeTagPrefix()
        alias = KeyStoreTestSupport.makeAlias()
        let keyStore = UUKeyStore(
            tagPrefix: tagPrefix!,
            requireSecureEnclave: true,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        let privateKey = try await keyStore.loadKey(alias: alias!).get()

        XCTAssertTrue(KeyStoreTestSupport.isSecureEnclaveBacked(privateKey))
        XCTAssertTrue(KeyStoreTestSupport.isPrivateKeyExportBlocked(privateKey))
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(
            privateKey,
            algorithm: KeyStoreTestSupport.defaultAlgorithm()))

        let plaintext = Data("secure-enclave-host".utf8)
        let decrypted = try KeyStoreTestSupport.eciesRoundTrip(privateKey: privateKey, plaintext: plaintext)
        XCTAssertEqual(decrypted, plaintext)
    }
}

// MARK: - Test support

private enum TestAliases
{
    static let primary = "primary-key"
    static let secondary = "secondary-key"
}

#endif
