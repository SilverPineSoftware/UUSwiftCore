//
//  UUSecurity.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/23/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Shared security facade that wires one ``UUKeyStore`` with ``UUCrypto`` for app-wide ECIES.
//
//  Use ``UUSecurity/keyStore`` and ``UUSecurity/crypto`` together so encryption and key material
//  resolve through the same underlying store. Apps typically call these static members directly
//  rather than creating separate ``UUKeyStore`` and ``UUCrypto`` instances.
//

#if os(iOS) || os(macOS)

import CryptoKit
import Foundation

/// Shared security services for device-bound key storage and ECIES encryption.
///
/// ``keyStore`` and ``crypto`` are configured together at launch. The key store enables Secure
/// Enclave backing when ``SecureEnclave/isAvailable`` is true; otherwise keys are stored in the
/// Keychain with the same access-control model as ``UUKeyStore``.
///
/// ```swift
/// let encrypted = await UUSecurity.crypto.encrypt(value: plaintext)
/// let decrypted = await UUSecurity.crypto.decrypt(value: try encrypted.get())
/// ```
///
/// For feature-specific aliases, pass a per-call ``keyAlias`` to ``UUCrypto/encrypt(value:keyAlias:)``
/// or create a dedicated ``UUCrypto`` instance that shares ``keyStore``.
public struct UUSecurity
{
    /// Default reverse-DNS alias used by ``crypto`` when no per-call override is supplied.
    internal static let defaultCryptoKeyAlias = "com.silverpine.uu.core.security.UUCrypto"
    
    /// Shared key store used by ``crypto`` and available for custom ``UUCrypto`` instances.
    ///
    /// ``UUKeyStoreProtocol/requireSecureEnclave`` is set from ``SecureEnclave/isAvailable`` so
    /// Simulator and macOS development use Keychain-backed keys while physical iOS devices use
    /// the Secure Enclave when hardware is present.
    public static let keyStore: UUKeyStoreProtocol = UUKeyStore(
        requireSecureEnclave: SecureEnclave.isAvailable
    )
    
    /// Shared ECIES helper bound to ``defaultCryptoKeyAlias`` and ``keyStore``.
    public static let crypto: UUCrypto = UUCrypto(
        keyAlias: Self.defaultCryptoKeyAlias,
        keyStore: Self.keyStore)
}


#endif
