//
//  UUEncryptedKeychain.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/23/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Keychain storage that encrypts logical values with ``UUCrypto`` before persistence.
//
//  ``UUEncryptedKeychain`` subclasses ``UUKeychainBase`` and overrides the transform hooks to
//  ECIES-encrypt on write and decrypt on read. The Keychain therefore holds ciphertext while callers
//  of ``UUKeychain/read(key:)`` and ``write(key:accessLevel:data:)`` work with plaintext.
//

#if os(iOS) || os(macOS)

import Foundation

// MARK: - Implementation

/// ``UUKeychainBase`` that encrypts and decrypts values with an injected ``UUCrypto``.
///
/// Each account ``key`` is passed to ``UUCrypto/encrypt(value:keyAlias:)`` and
/// ``UUCrypto/decrypt(value:keyAlias:)`` as the per-item ``keyAlias``, so distinct Keychain keys
/// resolve distinct EC key material when using the default ``UUSecurity/crypto`` configuration.
///
/// ```swift
/// let keychain = UUEncryptedKeychain(
///     serviceIdentifier: "com.example.app.encrypted-secrets",
///     crypto: UUSecurity.crypto)
///
/// _ = await keychain.write(
///     key: "refresh-token",
///     accessLevel: .afterFirstUnlockThisDeviceOnly,
///     data: tokenData)
/// ```
public final class UUEncryptedKeychain: UUKeychainBase, @unchecked Sendable
{
    private let crypto: any UUCrypto

    /// Creates an encrypted Keychain accessor.
    ///
    /// - Parameters:
    ///   - serviceIdentifier: Value stored in ``kSecAttrService`` for all items.
    ///   - accessGroup: Optional ``kSecAttrAccessGroup`` for shared access with extensions.
    ///   - crypto: ECIES helper used to transform logical bytes before storage.
    public init(
        serviceIdentifier: String,
        accessGroup: String? = nil,
        crypto: any UUCrypto)
    {
        self.crypto = crypto
        super.init(serviceIdentifier: serviceIdentifier, accessGroup: accessGroup)
    }

    public override func transformForWrite(
        key: String,
        accessLevel: UUKeychainAccessLevel,
        data: Data) async -> Result<Data, UUKeychainError>
    {
        switch await crypto.encrypt(value: data, keyAlias: key)
        {
            case .success(let encrypted):
                guard let encrypted else
                {
                    return .failure(.emptyData)
                }

                guard !encrypted.isEmpty else
                {
                    return .failure(.emptyData)
                }

                return .success(encrypted)

            case .failure(let error):
                return .failure(.transformFailed(underlying: error))
        }
    }

    public override func transformForRead(
        key: String,
        storedData: Data) async -> Result<Data, UUKeychainError>
    {
        switch await crypto.decrypt(value: storedData, keyAlias: key)
        {
            case .success(let decrypted):
                guard let decrypted else
                {
                    return .failure(.unexpectedData)
                }

                return .success(decrypted)

            case .failure(let error):
                return .failure(.transformFailed(underlying: error))
        }
    }
}


#endif
