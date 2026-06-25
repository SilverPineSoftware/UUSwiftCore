//
//  UUCrypto.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/23/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  ECIES encrypt and decrypt helpers for small payloads using device-bound EC keys from a ``UUKeyStore``.
//
//  ``UUCrypto`` defines async encrypt and decrypt operations scoped by key alias.
//  ``UUDeviceCrypto`` implements the protocol as a struct that loads private keys from an injected
//  ``UUKeyStore`` (typically ``UUDeviceKeyStore``). Apps typically expose a shared instance per app
//  or feature boundary (for example ``UUSecurity/crypto``).
//

#if os(iOS) || os(macOS)

import Foundation
import Security

// MARK: - UUCrypto

/// Async ECIES encryption scoped by key alias and backed by ``UUKeyStore``.
///
/// Inject a ``UUCrypto`` (or test double) instead of calling Security framework APIs directly.
/// Apps typically define a shared instance:
///
/// ```swift
/// struct AppCrypto {
///     static let shared: any UUCrypto = UUDeviceCrypto(
///         keyAlias: "com.example.app.crypto",
///         keyStore: AppKeyStore.shared)
/// }
/// ```
///
/// ``nil`` and empty ``Data`` inputs are passed through unchanged on both encrypt and decrypt.
public protocol UUCrypto: Sendable
{
    /// Encrypts ``value`` with the public key for ``keyAlias``.
    ///
    /// - Parameters:
    ///   - value: Plaintext bytes. ``nil`` and empty data are returned unchanged without touching the key store.
    ///   - keyAlias: Reverse-DNS alias passed to ``UUKeyStore/loadKey(alias:)``. When empty, the
    ///     instance default from ``UUDeviceCrypto/init(keyAlias:keyStore:)`` is used.
    /// - Returns: ECIES ciphertext on success, or a ``UUCryptoError`` on failure.
    func encrypt(value: Data?, keyAlias: String) async -> Result<Data?, UUCryptoError>

    /// Decrypts ``value`` with the private key for ``keyAlias``.
    ///
    /// - Parameters:
    ///   - value: Ciphertext produced by ``encrypt(value:keyAlias:)``. ``nil`` and empty data are returned
    ///     unchanged without touching the key store.
    ///   - keyAlias: Reverse-DNS alias passed to ``UUKeyStore/loadKey(alias:)``. When empty, the
    ///     instance default from ``UUDeviceCrypto/init(keyAlias:keyStore:)`` is used.
    /// - Returns: Plaintext bytes on success, or a ``UUCryptoError`` on failure.
    func decrypt(value: Data?, keyAlias: String) async -> Result<Data?, UUCryptoError>
}

public extension UUCrypto
{
    /// Encrypts ``value`` using the instance default ``keyAlias``.
    func encrypt(value: Data?) async -> Result<Data?, UUCryptoError>
    {
        return await encrypt(value: value, keyAlias: "")
    }
    
    /// Decrypts ``value`` using the instance default ``keyAlias``.
    func decrypt(value: Data?) async -> Result<Data?, UUCryptoError>
    {
        return await decrypt(value: value, keyAlias: "")
    }
}

// MARK: - UUDeviceCrypto

/// Default ``UUCrypto`` implementation using ``SecKeyCreateEncryptedData`` and
/// ``SecKeyCreateDecryptedData`` with the algorithm from the injected ``UUKeyStore``.
///
/// Each operation loads (or generates) the private key for the resolved alias, derives the public key,
/// and performs ECIES using the key store's ``algorithm`` property. Ciphertext format is defined by the
/// Security framework for the configured algorithm (default: variable-IV X9.63 SHA-256 AES-GCM).
public struct UUDeviceCrypto: UUCrypto
{
    private let keyAlias: String
    private let keyStore: any UUKeyStore
    
    /// Creates a crypto helper bound to a default alias and key store.
    ///
    /// - Parameters:
    ///   - keyAlias: Default reverse-DNS alias when ``encrypt(value:keyAlias:)`` or
    ///     ``decrypt(value:keyAlias:)`` is called with an empty ``keyAlias``.
    ///   - keyStore: Source of private ``SecKey`` references (typically a shared ``UUDeviceKeyStore``).
    public init(
        keyAlias: String,
        keyStore: any UUKeyStore)
    {
        self.keyAlias = keyAlias
        self.keyStore = keyStore
    }
    
    /// Encrypts ``value`` with the public key for the resolved alias.
    public func encrypt(value: Data?, keyAlias: String = "") async -> Result<Data?, UUCryptoError>
    {
        // Null in --> Null Out
        guard let unencryptedInput = value else
        {
            return .success(value)
        }
        
        // Empty in --> Empty Out
        guard !unencryptedInput.isEmpty else
        {
            return .success(value)
        }
        
        let alias = getAlias(keyAlias)
        
        let privateKey: SecKey
        
        switch (await keyStore.loadKey(alias: alias))
        {
            case .failure(let err):
                return .failure(.keyStoreError(err))
            
            case .success(let loadedKey):
                privateKey = loadedKey
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else
        {
            return .failure(.noPublicKey)
        }

        var error: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(
            publicKey,
            keyStore.algorithm,
            unencryptedInput as CFData,
            &error) as Data?
        else
        {
            return .failure(.encryptionFailed(underlying: error?.takeRetainedValue()))
        }

        return .success(encryptedData)
    }
    
    /// Decrypts ``value`` with the private key for the resolved alias.
    public func decrypt(value: Data?, keyAlias: String = "") async -> Result<Data?, UUCryptoError>
    {
        // Null in --> Null Out
        guard let encryptedInput = value else
        {
            return .success(value)
        }
        
        // Empty in --> Empty Out
        guard !encryptedInput.isEmpty else
        {
            return .success(value)
        }
        
        let alias = getAlias(keyAlias)
        
        let privateKey: SecKey
        
        switch (await keyStore.loadKey(alias: alias))
        {
            case .failure(let err):
                return .failure(.keyStoreError(err))
            
            case .success(let loadedKey):
                privateKey = loadedKey
        }
        
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            keyStore.algorithm,
            encryptedInput as CFData,
            &error) as Data?
        else
        {
            return .failure(.decryptionFailed(underlying: error?.takeRetainedValue()))
        }

        return .success(decryptedData)
    }
    
    private func getAlias(_ alias: String) -> String
    {
        if (alias.isEmpty)
        {
            return keyAlias
        }
        
        return alias
    }
}


#endif
