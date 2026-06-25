//
//  UUCryptoError.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/23/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Errors returned by ``UUCrypto`` and ``UUDeviceCrypto`` when ECIES encryption or decryption fails.
//

#if os(iOS) || os(macOS)

import Foundation

/// Errors produced by ``UUCrypto`` and ``UUDeviceCrypto``.
public enum UUCryptoError: Error, Sendable
{
    /// ``UUKeyStore/loadKey(alias:)`` failed while resolving the private key for encryption or decryption.
    case keyStoreError(UUKeyStoreError)

    /// The loaded private key has no associated public key (unexpected for EC keys).
    case noPublicKey

    /// ``SecKeyCreateEncryptedData`` failed.
    case encryptionFailed(underlying: Error?)

    /// ``SecKeyCreateDecryptedData`` failed (for example malformed or wrong-key ciphertext).
    case decryptionFailed(underlying: Error?)
}

extension UUCryptoError: LocalizedError
{
    public var errorDescription: String?
    {
        switch self
        {
            case .keyStoreError(let err):
                return "KeyStore error: \(err.localizedDescription)"
            
            case .noPublicKey:
                return "Failed to get public key."
            
            case .encryptionFailed(let underlying):
                if let underlying
                {
                    return "Encryption failed: \(underlying.localizedDescription)"
                }

                return "Encryption failed."
            
            case .decryptionFailed(let underlying):
                if let underlying
                {
                    return "Decryption failed: \(underlying.localizedDescription)"
                }

                return "Decryption failed."
        }
    }
}

#endif
