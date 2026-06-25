//
//  UUKeyStore.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/22/26.
//
//  Async Keychain Services storage for elliptic-curve ``SecKey`` references on iOS and macOS.
//
//  ``UUKeyStore`` defines scoped load and delete operations for device-bound private keys.
//  ``UUDeviceKeyStore`` implements the protocol as an actor, storing keys under ``kSecAttrApplicationTag``.
//  Apps typically expose a shared instance per app or feature boundary
//  (for example `AppKeyStore.shared`).
//

#if os(iOS) || os(macOS)

import CryptoKit
import Foundation
@preconcurrency import Security

extension SecKey: @unchecked @retroactive Sendable {}

// MARK: - Errors

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


// MARK: - UUKeyStore

/// Async Keychain storage for elliptic-curve private keys identified by alias and optional ``accessGroup``.
///
/// Inject a ``UUKeyStore`` (or test double) instead of calling Security framework key APIs
/// directly. The alias passed to ``loadKey(alias:)`` is stored as UTF-8 ``kSecAttrApplicationTag``
/// data (reverse-DNS strings are recommended).
///
/// Apps typically define a shared instance:
///
/// ```swift
/// struct AppKeyStore {
///     static let shared: any UUKeyStore = UUDeviceKeyStore()
/// }
/// ```
public protocol UUKeyStore: Sendable
{
    /// Optional Keychain access group for app extensions, mapped to ``kSecAttrAccessGroup``.
    var accessGroup: String? { get }

    /// EC key size in bits. P-256 uses 256. Required to be 256 when ``requireSecureEnclave`` is true.
    var keySizeBits: Int { get }

    /// When true, keys are created in the Secure Enclave and must be P-256.
    var requireSecureEnclave: Bool { get }

    /// Algorithm used to validate that loaded keys support expected encrypt/decrypt operations.
    var algorithm: SecKeyAlgorithm { get }

    /// Keychain accessibility applied via ``SecAccessControlCreateWithFlags`` when keys are created.
    var accessLevel: UUKeychainAccessLevel { get }

    /// Loads or generates a private ``SecKey`` for ``alias``.
    ///
    /// Looks up an existing key in the Keychain. When none is found, generates a new P-256 EC key.
    /// Invalid entries (for example a Keychain key when Secure Enclave is required) are deleted and
    /// replaced.
    func loadKey(alias: String) async -> Result<SecKey, UUKeyStoreError>

    /// Removes the key for ``alias``. Succeeds when the key is already absent.
    func deleteKey(alias: String) async -> UUKeyStoreError?
}

// MARK: - UUDeviceKeyStore

/// Default ``UUKeyStore`` implementation backed by Keychain Services ``kSecClassKey`` items.
///
/// Each instance is isolated to an actor so Security framework calls are serialized. Use unique
/// reverse-DNS aliases to avoid collisions across features or apps.
///
/// When ``requireSecureEnclave`` is true, keys are created with ``kSecAttrTokenIDSecureEnclave`` and
/// ``SecAccessControlCreateFlags/privateKeyUsage``. Otherwise keys are stored in the Keychain with
/// the same ``SecAccessControl`` accessibility model.
public actor UUDeviceKeyStore: UUKeyStore
{
    private static let secureEnclaveKeySizeBits = 256

    public let accessGroup: String?
    public let keySizeBits: Int
    public let requireSecureEnclave: Bool
    public let algorithm: SecKeyAlgorithm
    public let accessLevel: UUKeychainAccessLevel

    /// Creates a Keychain key store.
    ///
    /// - Parameters:
    ///   - accessGroup: Optional ``kSecAttrAccessGroup`` for shared access with extensions.
    ///   - keySizeBits: EC key size in bits. Defaults to 256 (P-256).
    ///   - requireSecureEnclave: When true, keys are created in the Secure Enclave when hardware is available.
    ///   - algorithm: ``SecKeyAlgorithm`` used to validate loaded keys. Defaults to documented ECIES variable-IV AES-GCM.
    ///   - accessLevel: Keychain accessibility embedded in ``SecAccessControl`` for new keys.
    public init(
        accessGroup: String? = nil,
        keySizeBits: Int = 256,
        requireSecureEnclave: Bool = true,
        algorithm: SecKeyAlgorithm = .eciesEncryptionStandardVariableIVX963SHA256AESGCM,
        accessLevel: UUKeychainAccessLevel = .afterFirstUnlockThisDeviceOnly)
    {
        self.accessGroup = accessGroup
        self.keySizeBits = keySizeBits
        self.requireSecureEnclave = requireSecureEnclave
        self.algorithm = algorithm
        self.accessLevel = accessLevel
    }

    // MARK: UUKeyStore

    /// Loads or generates a private ``SecKey`` stored under ``alias``.
    ///
    /// - Parameter alias: Value stored in ``kSecAttrApplicationTag`` (UTF-8). Must not be empty.
    /// - Returns: A ``SecKey`` private key reference on success, or a ``UUKeyStoreError`` on failure.
    public func loadKey(alias: String) async -> Result<SecKey, UUKeyStoreError>
    {
        if requireSecureEnclave && keySizeBits != Self.secureEnclaveKeySizeBits
        {
            return .failure(.keySizeNotSupported(keySize: keySizeBits))
        }

        switch await loadExisting(alias)
        {
            case .success(let key):
                return .success(key)

            case .failure(.notFound):
                break

            case .failure(.invalidEntry):
                _ = await deleteKey(alias: alias)

            case .failure(let error):
                return .failure(error)
        }

        return await createKey(alias)
    }

    /// Removes the private key stored under ``alias``.
    ///
    /// - Parameter alias: Value stored in ``kSecAttrApplicationTag`` (UTF-8). Must not be empty.
    /// - Returns: `nil` on success (including when the key is already absent), or a ``UUKeyStoreError`` on failure.
    public func deleteKey(alias: String) async -> UUKeyStoreError?
    {
        let tag: Data

        switch buildTag(alias)
        {
            case .failure(let err):
                return err

            case .success(let value):
                tag = value
        }

        let status = SecItemDelete(clearQuery(tag))
        switch status
        {
            case errSecSuccess, errSecItemNotFound:
                return nil

            default:
                return UUKeyStoreError(status)
        }
    }

    // MARK: Private

    private func buildTag(_ alias: String) -> Result<Data, UUKeyStoreError>
    {
        guard !alias.isEmpty else
        {
            return .failure(.invalidAlias)
        }

        guard let tag = alias.data(using: .utf8) else
        {
            return .failure(.invalidAlias)
        }

        return .success(tag)
    }

    private func loadExisting(_ alias: String) async -> Result<SecKey, UUKeyStoreError>
    {
        let tag: Data

        switch buildTag(alias)
        {
            case .failure(let err):
                return .failure(err)

            case .success(let value):
                tag = value
        }

        let query = loadQuery(tag)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)

        switch status
        {
            case errSecSuccess:
                guard let key = item as! SecKey? else
                {
                    return .failure(.invalidEntry)
                }

                if requireSecureEnclave && !isSecureEnclaveBacked(key)
                {
                    return .failure(.invalidEntry)
                }

                guard supportsAlgorithm(key) else
                {
                    return .failure(.invalidEntry)
                }

                return .success(key)

            case errSecItemNotFound:
                return .failure(.notFound)

            default:
                return .failure(UUKeyStoreError(status))
        }
    }

    private func createKey(_ alias: String) async -> Result<SecKey, UUKeyStoreError>
    {
        let tag: Data

        switch buildTag(alias)
        {
            case .failure(let err):
                return .failure(err)

            case .success(let value):
                tag = value
        }

        if requireSecureEnclave
        {
            guard keySizeBits == Self.secureEnclaveKeySizeBits else
            {
                return .failure(.keySizeNotSupported(keySize: keySizeBits))
            }

            guard SecureEnclave.isAvailable else
            {
                return .failure(.secureEnclaveUnavailable)
            }
        }

        let params: NSDictionary

        switch createAccessControl()
        {
            case .failure(let err):
                return .failure(err)

            case .success(let accessControl):
                params = createQuery(tag, accessControl)
        }

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(params, &error) else
        {
            let nsError = error?.takeRetainedValue() as? NSError
            if nsError?.code == Int(errSecDuplicateItem)
            {
                return await loadExisting(alias)
            }

            return .failure(.keyGenerationFailed(underlying: nsError))
        }

        guard supportsAlgorithm(key) else
        {
            _ = await deleteKey(alias: alias)
            return .failure(.keyAlgorithmUnsupported)
        }

        if requireSecureEnclave && !isSecureEnclaveBacked(key)
        {
            _ = await deleteKey(alias: alias)
            return .failure(.secureEnclaveUnavailable)
        }

        return .success(key)
    }

    private func supportsAlgorithm(_ key: SecKey) -> Bool
    {
        guard let publicKey = SecKeyCopyPublicKey(key) else
        {
            return false
        }

        return SecKeyIsAlgorithmSupported(publicKey, .encrypt, self.algorithm)
            && SecKeyIsAlgorithmSupported(key, .decrypt, self.algorithm)
    }

    private func isSecureEnclaveBacked(_ key: SecKey) -> Bool
    {
        guard let attributes = SecKeyCopyAttributes(key) as? [String: Any],
              let tokenID = attributes[kSecAttrTokenID as String] as? String
        else
        {
            return false
        }

        return tokenID == (kSecAttrTokenIDSecureEnclave as String)
    }

    private func commonQuery(_ tag: Data) -> [AnyHashable: Any]
    {
        var query: [AnyHashable: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag : tag,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: keySizeBits,
        ]

        if let accessGroup
        {
            query[kSecAttrAccessGroup] = accessGroup
        }

        return query
    }

    private func loadQuery(_ tag: Data) -> CFDictionary
    {
        var query = commonQuery(tag)
        query[kSecReturnRef] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query as CFDictionary
    }

    private func createAccessControl() -> Result<SecAccessControl, UUKeyStoreError>
    {
        var flags: SecAccessControlCreateFlags = []
        if requireSecureEnclave
        {
            flags.insert(.privateKeyUsage)
        }

        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            self.accessLevel.value,
            flags,
            &error) else
        {
            return .failure(.accessControlFailed(underlying: error?.takeRetainedValue() as? NSError))
        }

        return .success(access)
    }

    private func createQuery(_ tag: Data, _ accessControl: SecAccessControl) -> CFDictionary
    {
        let privateKeyAttributes: [AnyHashable: Any] = [
            kSecAttrIsPermanent: true,
            kSecAttrIsExtractable: false,
            kSecAttrApplicationTag: tag,
            kSecAttrAccessControl: accessControl,
        ]

        var attributes: [AnyHashable: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: keySizeBits,
            kSecPrivateKeyAttrs: privateKeyAttributes,
        ]

        if requireSecureEnclave
        {
            attributes[kSecAttrTokenID] = kSecAttrTokenIDSecureEnclave
        }

        return attributes as CFDictionary
    }

    private func clearQuery(_ tag: Data) -> CFDictionary
    {
        commonQuery(tag) as CFDictionary
    }
}

#endif
