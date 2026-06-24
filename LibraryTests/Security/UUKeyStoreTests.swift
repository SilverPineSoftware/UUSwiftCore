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

// MARK: - Error assertions

private enum KeyStoreErrorExpectation
{
    case invalidAlias
    case notFound
    case duplicateItem
    case authFailed
    case interactionNotAllowed
    case missingEntitlement
    case secureEnclaveUnavailable
    case keySizeNotSupported(Int)
    case osStatus(OSStatus)

    func matches(_ error: UUKeyStoreError) -> Bool
    {
        switch (self, error)
        {
            case (.invalidAlias, .invalidAlias):
                return true

            case (.notFound, .notFound):
                return true

            case (.duplicateItem, .duplicateItem):
                return true

            case (.authFailed, .authFailed):
                return true

            case (.interactionNotAllowed, .interactionNotAllowed):
                return true

            case (.missingEntitlement, .missingEntitlement):
                return true

            case (.secureEnclaveUnavailable, .secureEnclaveUnavailable):
                return true

            case (.keySizeNotSupported(let expected), .keySizeNotSupported(keySize: let actual)):
                return expected == actual

            case (.osStatus(let expected), .osStatus(let actual)):
                return expected == actual

            default:
                return false
        }
    }
}

private func XCTAssertKeyStoreError(
    _ error: UUKeyStoreError,
    _ expected: KeyStoreErrorExpectation,
    file: StaticString = #filePath,
    line: UInt = #line)
{
    XCTAssertTrue(
        expected.matches(error),
        "Expected \(expected), got \(String(describing: error))",
        file: file,
        line: line)
}

private func XCTAssertKeyStoreError(
    _ error: UUKeyStoreError?,
    _ expected: KeyStoreErrorExpectation,
    file: StaticString = #filePath,
    line: UInt = #line)
{
    guard let error else
    {
        XCTFail("Expected \(expected), got nil", file: file, line: line)
        return
    }

    XCTAssertKeyStoreError(error, expected, file: file, line: line)
}

// MARK: - Error mapping

final class UUKeyStoreErrorTests: XCTestCase
{
    func test_init_mapsKnownOSStatuses() async
    {
        XCTAssertKeyStoreError(UUKeyStoreError(errSecItemNotFound), .notFound)
        XCTAssertKeyStoreError(UUKeyStoreError(errSecDuplicateItem), .duplicateItem)
        XCTAssertKeyStoreError(UUKeyStoreError(errSecAuthFailed), .authFailed)
        XCTAssertKeyStoreError(UUKeyStoreError(errSecInteractionNotAllowed), .interactionNotAllowed)
        XCTAssertKeyStoreError(UUKeyStoreError(errSecMissingEntitlement), .missingEntitlement)
    }

    func test_init_mapsUnknownOSStatusToOsStatus() async
    {
        let status: OSStatus = -999
        XCTAssertKeyStoreError(UUKeyStoreError(status), .osStatus(status))
    }

    func test_errorDescription_isNonEmptyForAllCases() async
    {
        let errors: [UUKeyStoreError] = [
            .invalidAlias,
            .notFound,
            .invalidEntry,
            .keySizeNotSupported(keySize: 384),
            .keyGenerationFailed(underlying: nil),
            .accessControlFailed(underlying: nil),
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
    private var primaryAlias: String!
    private var secondaryAlias: String!

    override func setUp() async throws
    {
        try await super.setUp()
        let namespace = KeyStoreTestSupport.makeNamespace()
        primaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "primary-key")
        secondaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "secondary-key")
        keyStore = UUKeyStore(requireSecureEnclave: false)
    }

    override func tearDown() async throws
    {
        if let primaryAlias
        {
            KeyStoreTestSupport.deleteKey(alias: primaryAlias)
        }

        if let secondaryAlias
        {
            KeyStoreTestSupport.deleteKey(alias: secondaryAlias)
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
        XCTAssertKeyStoreError(error, .invalidAlias)
    }

    func test_loadKey_secureEnclaveRequired_returnsUnavailableWhenSecureEnclaveMissing() async throws
    {
        guard !SecureEnclave.isAvailable else
        {
            throw XCTSkip("Secure Enclave is available; unavailable-path test applies to Simulator and legacy Mac.")
        }

        let secureStore = UUKeyStore(requireSecureEnclave: true)
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
            keySizeBits: 384,
            requireSecureEnclave: true)
        let alias = KeyStoreTestSupport.makeAlias()

        let result = await secureStore.loadKey(alias: alias)

        guard case .failure(.keySizeNotSupported(keySize: 384)) = result else
        {
            XCTFail("Expected .keySizeNotSupported(keySize: 384), got \(result)")
            return
        }
    }
}

// MARK: - Keychain integration (Simulator and macOS)

final class UUKeyStoreIntegrationTests: XCTestCase
{
    private var primaryAlias: String!
    private var secondaryAlias: String!
    private var keyStore: UUKeyStore!

    override func setUp() async throws
    {
        try await super.setUp()

        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        let namespace = KeyStoreTestSupport.makeNamespace()
        primaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "primary-key")
        secondaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "secondary-key")
        keyStore = UUKeyStore(
            requireSecureEnclave: false,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
    }

    override func tearDown() async throws
    {
        if let primaryAlias
        {
            _ = await keyStore?.deleteKey(alias: primaryAlias)
            KeyStoreTestSupport.deleteKey(alias: primaryAlias)
        }

        if let secondaryAlias
        {
            _ = await keyStore?.deleteKey(alias: secondaryAlias)
            KeyStoreTestSupport.deleteKey(alias: secondaryAlias)
        }

        keyStore = nil
        try await super.tearDown()
    }

    func test_loadKey_createsAndReturnsPrivateKey() async throws
    {
        let result = await keyStore.loadKey(alias: primaryAlias)

        let privateKey = try XCTUnwrap(result.get())
        XCTAssertNotNil(SecKeyCopyPublicKey(privateKey))
        XCTAssertFalse(KeyStoreTestSupport.isSecureEnclaveBacked(privateKey))
    }

    func test_loadKey_isIdempotentForSameAlias() async throws
    {
        let first = try await keyStore.loadKey(alias: primaryAlias).get()
        let second = try await keyStore.loadKey(alias: primaryAlias).get()

        let algorithm = KeyStoreTestSupport.defaultAlgorithm()
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(first, algorithm: algorithm))
        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(second, algorithm: algorithm))
    }

    func test_loadKey_supportsConfiguredEciesAlgorithm() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: primaryAlias).get()

        XCTAssertTrue(KeyStoreTestSupport.supportsAlgorithm(
            privateKey,
            algorithm: KeyStoreTestSupport.defaultAlgorithm()))
    }

    func test_loadKey_eciesRoundTrip_succeeds() async throws
    {
        let privateKey = try await keyStore.loadKey(alias: primaryAlias).get()
        let plaintext = Data("keystore-round-trip".utf8)

        let decrypted = try KeyStoreTestSupport.eciesRoundTrip(
            privateKey: privateKey,
            plaintext: plaintext,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_deleteKey_removesStoredKey() async throws
    {
        _ = try await keyStore.loadKey(alias: primaryAlias).get()

        let deleteError = await keyStore.deleteKey(alias: primaryAlias)
        XCTAssertNil(deleteError)

        let reload = await keyStore.loadKey(alias: primaryAlias)
        XCTAssertNotNil(try? reload.get())
    }

    func test_deleteKey_isIdempotentWhenKeyIsMissing() async
    {
        let deleteError = await keyStore.deleteKey(alias: primaryAlias)
        XCTAssertNil(deleteError)
    }

    func test_sameAlias_isSharedAcrossKeyStoreInstances() async throws
    {
        let otherStore = UUKeyStore(requireSecureEnclave: false)

        let originalKey = try await keyStore.loadKey(alias: primaryAlias).get()
        let otherKey = try await otherStore.loadKey(alias: primaryAlias).get()

        let plaintext = Data("shared-alias".utf8)
        let decryptedOriginal = try KeyStoreTestSupport.eciesRoundTrip(privateKey: originalKey, plaintext: plaintext)
        let decryptedOther = try KeyStoreTestSupport.eciesRoundTrip(privateKey: otherKey, plaintext: plaintext)

        XCTAssertEqual(decryptedOriginal, plaintext)
        XCTAssertEqual(decryptedOther, plaintext)
    }

    func test_multipleAliases_storeIndependently() async throws
    {
        let keyA = try await keyStore.loadKey(alias: primaryAlias).get()
        let keyB = try await keyStore.loadKey(alias: secondaryAlias).get()

        let plaintextA = Data("alpha".utf8)
        let plaintextB = Data("beta".utf8)

        let decryptedA = try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyA, plaintext: plaintextA)
        let decryptedB = try KeyStoreTestSupport.eciesRoundTrip(privateKey: keyB, plaintext: plaintextB)

        XCTAssertEqual(decryptedA, plaintextA)
        XCTAssertEqual(decryptedB, plaintextB)
    }

    func test_concurrentLoadKeyFromSeparateStores_resolvesDuplicateItem() async throws
    {
        let alias = KeyStoreTestSupport.makeAlias()
        let storeA = UUKeyStore(requireSecureEnclave: false)
        let storeB = UUKeyStore(requireSecureEnclave: false)

        defer
        {
            KeyStoreTestSupport.deleteKey(alias: alias)
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
        let originalKey = try await keyStore.loadKey(alias: primaryAlias).get()
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

        _ = await keyStore.deleteKey(alias: primaryAlias)

        let replacementKey = try await keyStore.loadKey(alias: primaryAlias).get()
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
    private var alias: String?

    override func tearDown() async throws
    {
        if let alias
        {
            KeyStoreTestSupport.deleteKey(alias: alias)
        }

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

        alias = KeyStoreTestSupport.makeAlias()
        let keyStore = UUKeyStore(
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

#endif
