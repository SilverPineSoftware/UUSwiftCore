//
//  UUEncryptedKeychainTests.swift
//  UUSwiftCoreTests
//
//  Created by Ryan DeVore on 6/23/26.
//

#if os(iOS) || os(macOS)

import XCTest
@testable import UUSwiftCore

private let keychainIntegrationUnavailableMessage =
    "Keychain access requires a signed test host with keychain entitlements."

private enum TestKeys
{
    static let primary = "primary-key"
    static let secondary = "secondary-key"
}

// MARK: - Mock crypto

private struct PrefixMockCrypto: UUCryptoProtocol
{
    private let prefix = Data("enc:".utf8)

    func encrypt(value: Data?, keyAlias: String) async -> Result<Data?, UUCryptoError>
    {
        guard let value else
        {
            return .success(nil)
        }

        guard !value.isEmpty else
        {
            return .success(value)
        }

        return .success(prefix + value)
    }

    func decrypt(value: Data?, keyAlias: String) async -> Result<Data?, UUCryptoError>
    {
        guard let value else
        {
            return .success(nil)
        }

        guard !value.isEmpty else
        {
            return .success(value)
        }

        guard value.starts(with: prefix) else
        {
            return .failure(.decryptionFailed(underlying: nil))
        }

        return .success(value.dropFirst(prefix.count))
    }
}

private struct FailingMockCrypto: UUCryptoProtocol
{
    func encrypt(value: Data?, keyAlias: String) async -> Result<Data?, UUCryptoError>
    {
        return .failure(.encryptionFailed(underlying: nil))
    }

    func decrypt(value: Data?, keyAlias: String) async -> Result<Data?, UUCryptoError>
    {
        return .failure(.decryptionFailed(underlying: nil))
    }
}

// MARK: - Transform hooks

final class UUEncryptedKeychainTransformTests: XCTestCase
{
    private var keychain: UUEncryptedKeychain!

    override func setUp() async throws
    {
        try await super.setUp()
        keychain = UUEncryptedKeychain(
            serviceIdentifier: "com.uu.tests.encrypted-keychain.\(UUID().uuidString)",
            crypto: PrefixMockCrypto())
    }

    func test_transformForWrite_encryptsLogicalData() async
    {
        let plaintext = Data("secret".utf8)
        let result = await keychain.transformForWrite(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: plaintext)

        XCTAssertEqual(try? result.get(), Data("enc:secret".utf8))
    }

    func test_transformForRead_decryptsStoredData() async
    {
        let stored = Data("enc:secret".utf8)
        let result = await keychain.transformForRead(
            key: TestKeys.primary,
            storedData: stored)

        XCTAssertEqual(try? result.get(), Data("secret".utf8))
    }

    func test_write_returnsTransformFailedWhenEncryptionFails() async
    {
        let failingKeychain = UUEncryptedKeychain(
            serviceIdentifier: "com.uu.tests.encrypted-keychain.fail.\(UUID().uuidString)",
            crypto: FailingMockCrypto())

        let error = await failingKeychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("secret".utf8))

        guard case .transformFailed = error else
        {
            XCTFail("Expected .transformFailed, got \(String(describing: error))")
            return
        }
    }

    func test_read_returnsTransformFailedForMalformedStoredData() async throws
    {
        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("secret".utf8))
        XCTAssertNil(writeError)

        let plainKeychain = UUKeychain(serviceIdentifier: keychain.serviceIdentifier)
        let overwriteError = await plainKeychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: Data("not-encrypted".utf8))
        XCTAssertNil(overwriteError)

        let result = await keychain.read(key: TestKeys.primary)

        guard case .failure(.transformFailed) = result else
        {
            XCTFail("Expected .transformFailed, got \(result)")
            return
        }

        _ = await keychain.clear(key: TestKeys.primary)
    }
}

// MARK: - Keychain integration

final class UUEncryptedKeychainIntegrationTests: XCTestCase
{
    private var keychain: UUEncryptedKeychain!
    private var rawKeychain: UUKeychain!

    override func setUp() async throws
    {
        try await super.setUp()

        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        let serviceIdentifier = "com.uu.tests.encrypted-keychain.integration.\(UUID().uuidString)"
        keychain = UUEncryptedKeychain(
            serviceIdentifier: serviceIdentifier,
            crypto: PrefixMockCrypto())
        rawKeychain = UUKeychain(serviceIdentifier: serviceIdentifier)
    }

    override func tearDown() async throws
    {
        if let keychain
        {
            _ = await keychain.clear(key: TestKeys.primary)
            _ = await keychain.clear(key: TestKeys.secondary)
        }

        keychain = nil
        rawKeychain = nil
        try await super.tearDown()
    }

    func test_writeAndRead_roundTripsLogicalData() async
    {
        let payload = Data("encrypted-round-trip".utf8)

        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: payload)
        XCTAssertNil(writeError)

        let result = await keychain.read(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), payload)
    }

    func test_write_persistsTransformedBytesInKeychain() async
    {
        let payload = Data("stored-ciphertext".utf8)

        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: payload)
        XCTAssertNil(writeError)

        let rawResult = await rawKeychain.read(key: TestKeys.primary)
        XCTAssertEqual(try? rawResult.get(), Data("enc:stored-ciphertext".utf8))
    }

    func test_multipleKeys_storeIndependentValues() async
    {
        let payloadA = Data("alpha".utf8)
        let payloadB = Data("beta".utf8)

        let writeErrorA = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: payloadA)
        let writeErrorB = await keychain.write(
            key: TestKeys.secondary,
            accessLevel: .whenUnlocked,
            data: payloadB)
        XCTAssertNil(writeErrorA)
        XCTAssertNil(writeErrorB)

        let readA = try? await keychain.read(key: TestKeys.primary).get()
        let readB = try? await keychain.read(key: TestKeys.secondary).get()
        XCTAssertEqual(readA, payloadA)
        XCTAssertEqual(readB, payloadB)
    }
}

// MARK: - Crypto integration

final class UUEncryptedKeychainCryptoIntegrationTests: XCTestCase
{
    private var keychain: UUEncryptedKeychain!

    override func setUp() async throws
    {
        try await super.setUp()

        guard await KeyStoreTestSupport.isKeychainAccessible() else
        {
            throw XCTSkip(keychainIntegrationUnavailableMessage)
        }

        keychain = UUEncryptedKeychain(
            serviceIdentifier: "com.uu.tests.encrypted-keychain.crypto.\(UUID().uuidString)",
            crypto: UUCrypto(
                keyAlias: "com.uu.tests.encrypted-keychain.crypto",
                keyStore: UUDeviceKeyStore(requireSecureEnclave: false)))
    }

    override func tearDown() async throws
    {
        if let keychain
        {
            _ = await keychain.clear(key: TestKeys.primary)
        }

        keychain = nil
        try await super.tearDown()
    }

    func test_writeAndRead_roundTripsWithRealCrypto() async throws
    {
        let payload = Data("real-ecies-keychain".utf8)

        let writeError = await keychain.write(
            key: TestKeys.primary,
            accessLevel: .whenUnlocked,
            data: payload)
        XCTAssertNil(writeError)

        let result = await keychain.read(key: TestKeys.primary)
        XCTAssertEqual(try? result.get(), payload)

        let rawKeychain = UUKeychain(serviceIdentifier: keychain.serviceIdentifier)
        let rawResult = await rawKeychain.read(key: TestKeys.primary)
        let rawData = try XCTUnwrap(try? rawResult.get())
        XCTAssertNotEqual(rawData, payload)
    }
}

#endif
