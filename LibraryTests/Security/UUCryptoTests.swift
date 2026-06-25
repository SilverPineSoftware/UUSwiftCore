//
//  UUCryptoTests.swift
//  UUSwiftCoreTests
//
//  Created by Ryan DeVore on 6/23/26.
//

#if os(iOS) || os(macOS)

import Security
import XCTest
@testable import UUSwiftCore

private let keychainIntegrationUnavailableMessage =
    "Keychain access requires a signed test host with keychain entitlements."

// MARK: - Error assertions

private enum CryptoErrorExpectation
{
    case keyStoreInvalidAlias
    case keyStoreNotFound
    case noPublicKey
    case encryptionFailed
    case decryptionFailed

    func matches(_ error: UUCryptoError) -> Bool
    {
        switch (self, error)
        {
            case (.keyStoreInvalidAlias, .keyStoreError(.invalidAlias)):
                return true

            case (.keyStoreNotFound, .keyStoreError(.notFound)):
                return true

            case (.noPublicKey, .noPublicKey):
                return true

            case (.encryptionFailed, .encryptionFailed):
                return true

            case (.decryptionFailed, .decryptionFailed):
                return true

            default:
                return false
        }
    }
}

private func XCTAssertCryptoError(
    _ result: Result<Data?, UUCryptoError>,
    _ expected: CryptoErrorExpectation,
    file: StaticString = #filePath,
    line: UInt = #line)
{
    guard case .failure(let error) = result else
    {
        XCTFail("Expected failure \(expected), got success", file: file, line: line)
        return
    }

    XCTAssertTrue(
        expected.matches(error),
        "Expected \(expected), got \(String(describing: error))",
        file: file,
        line: line)
}

// MARK: - Errors

final class UUCryptoErrorTests: XCTestCase
{
    func test_errorDescription_isNonEmptyForAllCases() async
    {
        let errors: [UUCryptoError] = [
            .keyStoreError(.invalidAlias),
            .keyStoreError(.notFound),
            .noPublicKey,
            .encryptionFailed(underlying: nil),
            .encryptionFailed(underlying: NSError(domain: "test", code: 1)),
            .decryptionFailed(underlying: nil),
            .decryptionFailed(underlying: NSError(domain: "test", code: 2)),
        ]

        for error in errors
        {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Missing description for \(error)")
        }
    }

    func test_keyStoreError_wrapsUnderlyingLocalizedDescription() async
    {
        let error = UUCryptoError.keyStoreError(.invalidAlias)
        XCTAssertTrue(error.localizedDescription.contains("KeyStore error:"))
        XCTAssertTrue(error.localizedDescription.contains(UUKeyStoreError.invalidAlias.localizedDescription))
    }
}

// MARK: - Validation (mock key store)

final class UUCryptoValidationTests: XCTestCase
{
    private var crypto: UUDeviceCrypto!
    private var mockKeyStore: MockUUKeyStore!

    override func setUp() async throws
    {
        try await super.setUp()
        mockKeyStore = MockUUKeyStore()
        crypto = UUDeviceCrypto(keyAlias: "com.uu.tests.crypto.default", keyStore: mockKeyStore)
    }

    func test_encrypt_returnsNilWithoutCallingKeyStore() async
    {
        let result = await crypto.encrypt(value: nil)

        XCTAssertNil(try? result.get())
        let callCount = await mockKeyStore.loadKeyCallCount
        XCTAssertEqual(callCount, 0)
    }

    func test_encrypt_returnsEmptyWithoutCallingKeyStore() async
    {
        let empty = Data()
        let result = await crypto.encrypt(value: empty)

        XCTAssertEqual(try? result.get(), empty)
        let callCount = await mockKeyStore.loadKeyCallCount
        XCTAssertEqual(callCount, 0)
    }

    func test_decrypt_returnsNilWithoutCallingKeyStore() async
    {
        let result = await crypto.decrypt(value: nil)

        XCTAssertNil(try? result.get())
        let callCount = await mockKeyStore.loadKeyCallCount
        XCTAssertEqual(callCount, 0)
    }

    func test_decrypt_returnsEmptyWithoutCallingKeyStore() async
    {
        let empty = Data()
        let result = await crypto.decrypt(value: empty)

        XCTAssertEqual(try? result.get(), empty)
        let callCount = await mockKeyStore.loadKeyCallCount
        XCTAssertEqual(callCount, 0)
    }

    func test_protocolExtension_usesInstanceDefaultAlias() async throws
    {
        let plaintext = Data("protocol-default-alias".utf8)
        let encrypted = try await crypto.encrypt(value: plaintext).get()
        let decrypted = try await crypto.decrypt(value: encrypted).get()

        XCTAssertEqual(decrypted, plaintext)
        let loadedAlias = await mockKeyStore.lastLoadedAlias
        XCTAssertEqual(loadedAlias, "com.uu.tests.crypto.default")
    }
}

// MARK: - Mock key store

final class UUCryptoMockKeyStoreTests: XCTestCase
{
    private var primaryAlias: String!
    private var secondaryAlias: String!
    private var mockKeyStore: MockUUKeyStore!
    private var crypto: UUDeviceCrypto!

    override func setUp() async throws
    {
        try await super.setUp()

        let namespace = KeyStoreTestSupport.makeNamespace()
        primaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "primary-key")
        secondaryAlias = KeyStoreTestSupport.qualifiedAlias(namespace: namespace, name: "secondary-key")
        mockKeyStore = MockUUKeyStore()
        crypto = UUDeviceCrypto(keyAlias: primaryAlias, keyStore: mockKeyStore)
    }

    func test_encrypt_propagatesKeyStoreError() async
    {
        await mockKeyStore.setLoadKeyResult(.failure(.invalidAlias))

        let result = await crypto.encrypt(value: Data("secret".utf8))

        XCTAssertCryptoError(result, .keyStoreInvalidAlias)
    }

    func test_decrypt_propagatesKeyStoreError() async
    {
        await mockKeyStore.setLoadKeyResult(.failure(.notFound))

        let result = await crypto.decrypt(value: Data([0x01, 0x02, 0x03]))

        XCTAssertCryptoError(result, .keyStoreNotFound)
    }

    func test_encryptAndDecrypt_roundTrip_succeeds() async throws
    {
        let plaintext = Data("Hello, world!".utf8)
        let encrypted = try await crypto.encrypt(value: plaintext).get()
        let decrypted = try await crypto.decrypt(value: encrypted).get()

        XCTAssertNotNil(encrypted)
        XCTAssertFalse(encrypted!.isEmpty)
        XCTAssertEqual(decrypted, plaintext)
    }

    func test_encrypt_producesDifferentCiphertextForSamePlaintext() async throws
    {
        let plaintext = Data("non-deterministic-iv".utf8)
        let first = try await crypto.encrypt(value: plaintext).get()
        let second = try await crypto.encrypt(value: plaintext).get()

        XCTAssertNotEqual(first, second)

        let decryptedFirst = try await crypto.decrypt(value: first).get()
        let decryptedSecond = try await crypto.decrypt(value: second).get()
        XCTAssertEqual(decryptedFirst, plaintext)
        XCTAssertEqual(decryptedSecond, plaintext)
    }

    func test_decrypt_malformedCiphertext_returnsFailure() async throws
    {
        _ = try await crypto.encrypt(value: Data("warm-up".utf8)).get()

        let result = await crypto.decrypt(value: Data([0x01, 0x02, 0x03]))

        XCTAssertCryptoError(result, .decryptionFailed)
    }

    func test_perCallAliasOverride_usesSpecifiedAlias() async throws
    {
        let plaintextA = Data("alpha".utf8)
        let plaintextB = Data("beta".utf8)

        let encryptedA = try await crypto.encrypt(value: plaintextA, keyAlias: primaryAlias).get()
        let encryptedB = try await crypto.encrypt(value: plaintextB, keyAlias: secondaryAlias).get()

        let decryptedA = try await crypto.decrypt(value: encryptedA, keyAlias: primaryAlias).get()
        let decryptedB = try await crypto.decrypt(value: encryptedB, keyAlias: secondaryAlias).get()
        XCTAssertEqual(decryptedA, plaintextA)
        XCTAssertEqual(decryptedB, plaintextB)

        let wrongKeyResult = await crypto.decrypt(value: encryptedA, keyAlias: secondaryAlias)
        XCTAssertCryptoError(wrongKeyResult, .decryptionFailed)
    }
}

// MARK: - Keychain integration (Simulator and macOS)

final class UUCryptoIntegrationTests: XCTestCase
{
    private var primaryAlias: String!
    private var secondaryAlias: String!
    private var keyStore: UUDeviceKeyStore!
    private var crypto: UUDeviceCrypto!

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
        keyStore = UUDeviceKeyStore(
            requireSecureEnclave: false,
            algorithm: KeyStoreTestSupport.defaultAlgorithm())
        crypto = UUDeviceCrypto(keyAlias: primaryAlias, keyStore: keyStore)
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

        crypto = nil
        keyStore = nil
        try await super.tearDown()
    }

    func test_encryptAndDecrypt_roundTrip_succeeds() async throws
    {
        let plaintext = Data("crypto-integration-round-trip".utf8)
        let encrypted = try await crypto.encrypt(value: plaintext).get()
        let decrypted = try await crypto.decrypt(value: encrypted).get()

        XCTAssertNotNil(encrypted)
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

    func test_multipleAliases_storeIndependentKeys() async throws
    {
        let plaintextA = Data("integration-alpha".utf8)
        let plaintextB = Data("integration-beta".utf8)

        let encryptedA = try await crypto.encrypt(value: plaintextA, keyAlias: primaryAlias).get()
        let encryptedB = try await crypto.encrypt(value: plaintextB, keyAlias: secondaryAlias).get()

        let decryptedA = try await crypto.decrypt(value: encryptedA, keyAlias: primaryAlias).get()
        let decryptedB = try await crypto.decrypt(value: encryptedB, keyAlias: secondaryAlias).get()
        XCTAssertEqual(decryptedA, plaintextA)
        XCTAssertEqual(decryptedB, plaintextB)
    }

    func test_sameAlias_isSharedAcrossCryptoInstances() async throws
    {
        let otherCrypto = UUDeviceCrypto(keyAlias: primaryAlias, keyStore: keyStore)
        let plaintext = Data("shared-crypto-alias".utf8)

        let encrypted = try await crypto.encrypt(value: plaintext).get()
        let decrypted = try await otherCrypto.decrypt(value: encrypted).get()

        XCTAssertEqual(decrypted, plaintext)
    }
}

// MARK: - Test support

private actor MockUUKeyStore: UUKeyStore
{
    let accessGroup: String? = nil
    let keySizeBits: Int = 256
    let requireSecureEnclave: Bool = false
    let algorithm: SecKeyAlgorithm = KeyStoreTestSupport.defaultAlgorithm()
    let accessLevel: UUKeychainAccessLevel = .afterFirstUnlockThisDeviceOnly

    private var keys: [String: SecKey] = [:]
    private var forcedLoadKeyResult: Result<SecKey, UUKeyStoreError>?

    private(set) var loadKeyCallCount = 0
    private(set) var lastLoadedAlias: String?

    func setLoadKeyResult(_ result: Result<SecKey, UUKeyStoreError>)
    {
        forcedLoadKeyResult = result
    }

    func loadKey(alias: String) async -> Result<SecKey, UUKeyStoreError>
    {
        loadKeyCallCount += 1
        lastLoadedAlias = alias

        if let forcedLoadKeyResult
        {
            return forcedLoadKeyResult
        }

        if let key = keys[alias]
        {
            return .success(key)
        }

        do
        {
            let key = try KeyStoreTestSupport.generateEphemeralPrivateKey()
            keys[alias] = key
            return .success(key)
        }
        catch
        {
            return .failure(.keyGenerationFailed(underlying: error))
        }
    }

    func deleteKey(alias: String) async -> UUKeyStoreError?
    {
        keys.removeValue(forKey: alias)
        return nil
    }
}

#endif
