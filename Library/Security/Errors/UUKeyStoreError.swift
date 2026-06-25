//
//  UUKeyStoreError.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/22/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Errors returned by ``UUKeyStore`` and ``UUDeviceKeyStore`` when loading, generating, or deleting
//  elliptic-curve private keys in the Keychain or Secure Enclave.
//

#if os(iOS) || os(macOS)

import Foundation
import Security

/// Errors produced by ``UUKeyStore`` and ``UUDeviceKeyStore``.
public enum UUKeyStoreError: Error, Sendable
{
    /// ``loadKey(alias:)`` or ``deleteKey(alias:)`` was called with an empty alias.
    case invalidAlias

    /// No key exists for the given alias.
    case notFound

    /// A matching keychain entry exists but is unusable (wrong backing, algorithm, or type).
    case invalidEntry

    /// ``requireSecureEnclave`` is true and ``keySizeBits`` is not 256 (P-256).
    case keySizeNotSupported(keySize: Int)

    /// ``SecKeyCreateRandomKey`` failed.
    case keyGenerationFailed(underlying: Error?)

    /// ``SecAccessControlCreateWithFlags`` failed while building key attributes.
    case accessControlFailed(underlying: Error?)

    /// The generated or loaded key does not support ``UUKeyStore/algorithm``.
    case keyAlgorithmUnsupported

    /// ``requireSecureEnclave`` is true but Secure Enclave hardware is unavailable.
    case secureEnclaveUnavailable

    /// ``SecKeyCreateRandomKey`` reported a duplicate item for the same tag.
    case duplicateItem

    /// Keychain authentication failed (for example biometrics or passcode).
    case authFailed

    /// Keychain interaction is not allowed in the current context.
    case interactionNotAllowed

    /// The process is missing Keychain entitlements (for example ``application-identifier``).
    case missingEntitlement

    /// An underlying Keychain ``OSStatus`` not mapped to a specific case.
    case osStatus(OSStatus)

    /// Creates an error from a Keychain ``OSStatus``.
    public init(_ status: OSStatus)
    {
        switch status
        {
            case errSecItemNotFound:
                self = .notFound

            case errSecDuplicateItem:
                self = .duplicateItem

            case errSecAuthFailed:
                self = .authFailed

            case errSecInteractionNotAllowed:
                self = .interactionNotAllowed

            case errSecMissingEntitlement:
                self = .missingEntitlement

            default:
                self = .osStatus(status)
        }
    }
}

extension UUKeyStoreError: LocalizedError
{
    public var errorDescription: String?
    {
        switch self
        {
            case .invalidAlias:
                return "Key alias must not be empty."

            case .notFound:
                return "Key not found."

            case .invalidEntry:
                return "Key entry is invalid."
            
            case .keySizeNotSupported(let size):
                return "Secure Enclave does not support \(size)-bit EC keys."

            case .keyGenerationFailed(let error):
                if let err = error
                {
                    return "Key generation failed: \(err.localizedDescription)"
                }

                return "Key generation failed."

            case .accessControlFailed(let error):
                if let err = error
                {
                    return "Failed to create access control object: \(err.localizedDescription)"
                }

                return "Failed to create access control object."

            case .keyAlgorithmUnsupported:
                return "Key algorithm is not supported."

            case .secureEnclaveUnavailable:
                return "Secure Enclave is not available."

            case .duplicateItem:
                return "Keychain item already exists."

            case .authFailed:
                return "Keychain authentication failed."

            case .interactionNotAllowed:
                return "Keychain interaction is not allowed."

            case .missingEntitlement:
                return "Keychain entitlements are missing for this process."

            case .osStatus(let status):
                if let message = SecCopyErrorMessageString(status, nil) as String?
                {
                    return "Keychain error (\(status)): \(message)"
                }

                return "Keychain error (\(status))."
        }
    }
}

#endif
