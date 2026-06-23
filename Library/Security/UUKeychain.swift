//
//  UUKeychain.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/16/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Async Keychain Services storage for generic passwords on iOS and macOS.
//
//  ``UUKeychainProtocol`` defines scoped read, write, and clear operations.
//  ``UUKeychain`` implements the protocol as an actor, namespacing items by
//  ``serviceIdentifier``. Apps typically expose a shared instance per app or
//  feature boundary (for example `AppKeychain.shared`).
//

#if os(iOS) || os(macOS)

import Foundation
import Security

// MARK: - Access level

/// Keychain item accessibility for ``UUKeychain/write(key:accessLevel:data:)``.
///
/// Maps to ``kSecAttrAccessible`` values used when an item is first created or updated.
public enum UUKeychainAccessLevel: Sendable
{
    /// ``kSecAttrAccessibleWhenUnlocked``
    case whenUnlocked

    /// ``kSecAttrAccessibleAfterFirstUnlock``
    case afterFirstUnlock

    /// ``kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly``
    case whenPasscodeSetThisDeviceOnly

    /// ``kSecAttrAccessibleWhenUnlockedThisDeviceOnly``
    case whenUnlockedThisDeviceOnly

    /// ``kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly``
    case afterFirstUnlockThisDeviceOnly
}

public extension UUKeychainAccessLevel
{
    /// The Security framework constant for this accessibility level.
    var value: CFTypeRef
    {
        switch self
        {
            case .whenUnlocked:
                return kSecAttrAccessibleWhenUnlocked

            case .afterFirstUnlock:
                return kSecAttrAccessibleAfterFirstUnlock

            case .whenPasscodeSetThisDeviceOnly:
                return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly

            case .whenUnlockedThisDeviceOnly:
                return kSecAttrAccessibleWhenUnlockedThisDeviceOnly

            case .afterFirstUnlockThisDeviceOnly:
                return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

// MARK: - Errors

/// Errors produced by ``UUKeychain`` and ``UUKeychainProtocol`` implementations.
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

            case .unexpectedData, .emptyData, .invalidKey, .invalidStringEncoding:
                return nil

            case .osStatus(let status):
                return status
        }
    }
}

// MARK: - Protocol

/// Async Keychain storage scoped by ``serviceIdentifier`` and optional ``accessGroup``.
///
/// Inject a ``UUKeychain`` instance (or test double) instead of using static Keychain helpers.
/// Apps typically define a shared instance:
///
/// ```swift
/// enum AppKeychain {
///     static let shared = UUKeychain(serviceIdentifier: "com.example.app.secrets")
/// }
/// ```
public protocol UUKeychainProtocol: Sendable
{
    /// Namespace for stored items, mapped to ``kSecAttrService``.
    var serviceIdentifier: String { get }

    /// Optional Keychain access group for app extensions, mapped to ``kSecAttrAccessGroup``.
    var accessGroup: String? { get }

    /// Reads the raw bytes for ``key``.
    func read(key: String) async -> Result<Data, UUKeychainError>

    /// Stores ``data`` for ``key``, replacing any existing item.
    ///
    /// - Returns: `nil` on success, or a ``UUKeychainError`` on failure.
    func write(key: String, accessLevel: UUKeychainAccessLevel, data: Data) async -> UUKeychainError?

    /// Removes the item for ``key``. Succeeds when the item is already absent.
    func clear(key: String) async -> UUKeychainError?
}

public extension UUKeychainProtocol
{
    /// Reads a string for ``key`` by decoding the stored bytes with ``encoding``.
    ///
    /// Delegates to ``read(key:)`` and converts the result to ``String``. When ``encoding`` is
    /// omitted, UTF-8 is used.
    ///
    /// - Parameters:
    ///   - key: Account name for the item, mapped to ``kSecAttrAccount``.
    ///   - encoding: Character encoding used to decode stored bytes. Defaults to UTF-8.
    /// - Returns: The decoded string on success, or a ``UUKeychainError`` on failure
    ///   (including ``UUKeychainError/notFound``, ``UUKeychainError/invalidKey``, and
    ///   ``UUKeychainError/unexpectedData`` when bytes cannot be decoded).
    func readString(key: String, encoding: String.Encoding = .utf8) async -> Result<String, UUKeychainError>
    {
        let result = await read(key: key)

        switch result
        {
            case .success(let data):
                guard let string = String(data: data, encoding: encoding) else
                {
                    return .failure(.unexpectedData)
                }

                return .success(string)

            case .failure(let error):
                return .failure(error)
        }
    }

    /// Stores ``string`` for ``key`` by encoding it with ``encoding`` and calling
    /// ``write(key:accessLevel:data:)``.
    ///
    /// When ``encoding`` is omitted, UTF-8 is used.
    ///
    /// - Parameters:
    ///   - key: Account name for the item, mapped to ``kSecAttrAccount``.
    ///   - accessLevel: Keychain accessibility applied when the item is created or updated.
    ///   - string: Value to store. Must not be empty.
    ///   - encoding: Character encoding used to produce stored bytes. Defaults to UTF-8.
    /// - Returns: `nil` on success, or a ``UUKeychainError`` on failure
    ///   (including ``UUKeychainError/emptyData``, ``UUKeychainError/invalidKey``, and
    ///   ``UUKeychainError/invalidStringEncoding`` when ``string`` cannot be encoded).
    func writeString(key: String, accessLevel: UUKeychainAccessLevel, string: String, encoding: String.Encoding = .utf8) async -> UUKeychainError?
    {
        guard !string.isEmpty else
        {
            return .emptyData
        }

        guard let data = string.data(using: encoding) else
        {
            return .invalidStringEncoding
        }

        return await write(key: key, accessLevel: accessLevel, data: data)
    }
}

// MARK: - Implementation

/// Default ``UUKeychainProtocol`` implementation backed by Keychain Services generic passwords.
///
/// Each instance is isolated to an actor so synchronous Security APIs do not block callers of
/// other concurrent work at the call site. Use a dedicated ``serviceIdentifier`` per app or
/// feature namespace.
public actor UUKeychain: UUKeychainProtocol
{
    public let serviceIdentifier: String
    public let accessGroup: String?

    /// Creates a Keychain accessor for the given service namespace.
    ///
    /// - Parameters:
    ///   - serviceIdentifier: Value stored in ``kSecAttrService`` for all items.
    ///   - accessGroup: Optional ``kSecAttrAccessGroup`` for shared access with extensions.
    public init(
        serviceIdentifier: String,
        accessGroup: String? = nil)
    {
        self.serviceIdentifier = serviceIdentifier
        self.accessGroup = accessGroup
    }

    /// Reads the raw bytes for ``key``.
    public func read(key: String) async -> Result<Data, UUKeychainError>
    {
        if let validationError = validate(key: key)
        {
            return .failure(validationError)
        }

        let query = readQuery(key)

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query, &result)

        guard status == errSecSuccess else
        {
            return .failure(UUKeychainError(status))
        }

        guard let data = result as? Data else
        {
            return .failure(.unexpectedData)
        }

        return .success(data)
    }

    /// Stores ``data`` for ``key``, replacing any existing item.
    public func write(
        key: String,
        accessLevel: UUKeychainAccessLevel,
        data: Data) async -> UUKeychainError?
    {
        if let validationError = validate(key: key)
        {
            return validationError
        }

        guard !data.isEmpty else
        {
            return .emptyData
        }

        let addQuery = writeQuery(key, accessLevel, data)
        var status = SecItemAdd(addQuery, nil)

        if status == errSecDuplicateItem
        {
            let matchQuery = commonQuery(key) as CFDictionary
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessLevel.value,
            ]

            status = SecItemUpdate(matchQuery, attributesToUpdate as CFDictionary)
        }

        guard status == errSecSuccess else
        {
            return UUKeychainError(status)
        }

        return nil
    }

    /// Removes the item for ``key``.
    public func clear(key: String) async -> UUKeychainError?
    {
        if let validationError = validate(key: key)
        {
            return validationError
        }

        let status = SecItemDelete(clearQuery(key))

        switch status
        {
            case errSecSuccess, errSecItemNotFound:
                return nil

            default:
                return UUKeychainError(status)
        }
    }

    // MARK: Private

    private func validate(key: String) -> UUKeychainError?
    {
        guard !key.isEmpty else
        {
            return .invalidKey
        }

        return nil
    }

    private func commonQuery(_ key: String) -> [String: Any]
    {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
        ]

        if let accessGroup
        {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func readQuery(_ key: String) -> CFDictionary
    {
        var query = commonQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query as CFDictionary
    }

    private func writeQuery(
        _ key: String,
        _ accessLevel: UUKeychainAccessLevel,
        _ data: Data) -> CFDictionary
    {
        var query = commonQuery(key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessLevel.value
        return query as CFDictionary
    }

    private func clearQuery(_ key: String) -> CFDictionary
    {
        commonQuery(key) as CFDictionary
    }
}

#endif
