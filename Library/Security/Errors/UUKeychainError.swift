//
//  UUKeychainError.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/16/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Errors returned by ``UUKeychain``, ``UUPlainKeychain``, ``UUEncryptedKeychain``, and
//  ``UUKeychainBase`` subclasses when reading, writing, or clearing generic-password Keychain items.
//

#if os(iOS) || os(macOS)

import Foundation
import Security

/// Errors produced by ``UUKeychain``, ``UUPlainKeychain``, and ``UUEncryptedKeychain``.
public enum UUKeychainError: Error, Equatable, Sendable
{
    /// No item exists for the given service and account key.
    case notFound

    /// ``SecItemAdd`` reported a duplicate item (rare when using the default upsert write path).
    case duplicateItem

    /// Authentication failed (for example biometrics or passcode).
    case authFailed

    /// Keychain interaction is not allowed in the current context.
    case interactionNotAllowed

    /// The process is missing Keychain entitlements (for example ``application-identifier``).
    case missingEntitlement

    /// The Keychain returned a value that was not ``Data``.
    case unexpectedData

    /// ``write(key:accessLevel:data:)`` or ``writeString(key:accessLevel:string:)`` was called with empty data.
    case emptyData

    /// ``read(key:)`` or ``write(key:accessLevel:data:)`` was called with an empty key.
    case invalidKey

    /// A string could not be encoded for storage.
    case invalidStringEncoding

    /// ``transformForWrite(key:accessLevel:data:)`` or ``transformForRead(key:storedData:)`` failed.
    case transformFailed(underlying: Error?)

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

    public static func == (lhs: UUKeychainError, rhs: UUKeychainError) -> Bool
    {
        switch (lhs, rhs)
        {
            case (.notFound, .notFound),
                 (.duplicateItem, .duplicateItem),
                 (.authFailed, .authFailed),
                 (.interactionNotAllowed, .interactionNotAllowed),
                 (.missingEntitlement, .missingEntitlement),
                 (.unexpectedData, .unexpectedData),
                 (.emptyData, .emptyData),
                 (.invalidKey, .invalidKey),
                 (.invalidStringEncoding, .invalidStringEncoding),
                 (.transformFailed, .transformFailed):
                return true

            case (.osStatus(let left), .osStatus(let right)):
                return left == right

            default:
                return false
        }
    }
}

extension UUKeychainError: LocalizedError
{
    public var errorDescription: String?
    {
        switch self
        {
            case .notFound:
                return "Keychain item not found."

            case .duplicateItem:
                return "Keychain item already exists."

            case .authFailed:
                return "Keychain authentication failed."

            case .interactionNotAllowed:
                return "Keychain interaction is not allowed."

            case .missingEntitlement:
                return "Keychain entitlements are missing for this process."

            case .unexpectedData:
                return "Keychain returned an unexpected value type."

            case .emptyData:
                return "Cannot write empty data to the keychain."

            case .invalidKey:
                return "Keychain key must not be empty."

            case .invalidStringEncoding:
                return "String could not be encoded for keychain storage."

            case .transformFailed(let underlying):
                if let underlying
                {
                    return "Keychain data transformation failed: \(underlying.localizedDescription)"
                }

                return "Keychain data transformation failed."

            case .osStatus(let status):
                if let message = SecCopyErrorMessageString(status, nil) as String?
                {
                    return "Keychain error (\(status)): \(message)"
                }

                return "Keychain error (\(status))."
        }
    }
}

public extension UUKeychainError
{
    /// The Keychain ``OSStatus`` when this error originated from Security framework APIs.
    var status: OSStatus?
    {
        switch self
        {
            case .notFound:
                return errSecItemNotFound

            case .duplicateItem:
                return errSecDuplicateItem

            case .authFailed:
                return errSecAuthFailed

            case .interactionNotAllowed:
                return errSecInteractionNotAllowed

            case .missingEntitlement:
                return errSecMissingEntitlement

            case .unexpectedData, .emptyData, .invalidKey, .invalidStringEncoding, .transformFailed:
                return nil

            case .osStatus(let status):
                return status
        }
    }
}

#endif
