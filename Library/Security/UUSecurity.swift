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
//  Shared security facade wiring one ``UUKeyStore``, ``UUCrypto``, and ``UUKeychain`` for app-wide use.
//
//  ``UUSecurity`` exposes static members configured together so EC key material, ECIES encryption,
//  and generic Keychain storage share consistent defaults. Apps typically call these members directly
//  rather than creating separate ``UUDeviceKeyStore``, ``UUDeviceCrypto``, and ``UUKeychain`` instances.
//

#if os(iOS) || os(macOS)

import CryptoKit
import Foundation

// MARK: - Facade

/// Shared security services for device-bound keys, ECIES encryption, and Keychain storage.
///
/// Three capabilities are wired at launch:
///
/// - ``keyStore`` — loads or generates P-256 private ``SecKey`` references (Secure Enclave when available).
/// - ``crypto`` — encrypts and decrypts small payloads with ECIES via ``keyStore``.
/// - ``keychain`` — stores generic passwords (tokens, credentials) under a fixed service namespace.
///
/// Use ``crypto`` when ciphertext must be bound to a device key pair. Use ``keychain`` when you need
/// to persist opaque bytes or strings that are not ECIES-wrapped. Both are independent; neither
/// replaces the other.
///
/// ```swift
/// // ECIES via the shared EC key
/// let encrypted = await UUSecurity.crypto.encrypt(value: plaintext)
/// let decrypted = await UUSecurity.crypto.decrypt(value: try encrypted.get())
///
/// // Generic password in Keychain
/// _ = await UUSecurity.keychain.write(
///     key: "refresh-token",
///     accessLevel: .afterFirstUnlockThisDeviceOnly,
///     data: tokenData)
/// ```
///
/// For feature-specific EC aliases, pass a per-call ``keyAlias`` to
/// ``UUCrypto/encrypt(value:keyAlias:)`` or create a dedicated ``UUDeviceCrypto`` instance that shares
/// ``keyStore``. For additional Keychain namespaces, create a separate ``UUPlainKeychain`` with its own
/// ``UUKeychain/serviceIdentifier``.
public struct UUSecurity
{
    /// Default reverse-DNS alias used by ``crypto`` when no per-call override is supplied.
    internal static let defaultCryptoKeyAlias = "com.silverpine.uu.core.security.UUCrypto"

    /// Service namespace passed to ``UUPlainKeychain/init(serviceIdentifier:accessGroup:)`` for ``keychain``.
    internal static let keychainServiceIdentifier = "com.silverpine.uu.core.security.UUKeychain"

    /// Shared key store used by ``crypto`` and available for custom ``UUCrypto`` instances.
    ///
    /// Default implementation is ``UUDeviceKeyStore``. ``UUKeyStore/requireSecureEnclave`` is set from
    /// ``SecureEnclave/isAvailable`` so Simulator and macOS development use Keychain-backed keys while
    /// physical iOS devices use the Secure Enclave when hardware is present.
    public static let keyStore: any UUKeyStore = UUDeviceKeyStore(
        requireSecureEnclave: SecureEnclave.isAvailable
    )

    /// Shared ECIES helper bound to ``defaultCryptoKeyAlias`` and ``keyStore``.
    ///
    /// Delegates key loading to ``keyStore`` on every encrypt and decrypt. ``nil`` and empty
    /// ``Data`` inputs are passed through unchanged; see ``UUCrypto``.
    public static let crypto: any UUCrypto = UUDeviceCrypto(
        keyAlias: Self.defaultCryptoKeyAlias,
        keyStore: Self.keyStore)

    /// Shared generic-password Keychain accessor scoped to ``keychainServiceIdentifier``.
    ///
    /// Default implementation is ``UUPlainKeychain``. Stores opaque secrets (for example API tokens)
    /// independently of the EC keys managed by ``keyStore``. Items are namespaced by account key via
    /// ``UUKeychain/read(key:)`` and ``UUKeychain/write(key:accessLevel:data:)``.
    public static let keychain: any UUKeychain = UUPlainKeychain(
        serviceIdentifier: Self.keychainServiceIdentifier)
}


#endif
