//
//  KeyStoreTestSupport.swift
//  UUSwiftCoreTests
//

#if os(iOS) || os(macOS)

import CryptoKit
import Foundation
import Security
@testable import UUSwiftCore

enum KeyStoreTestSupport
{
    static func makeNamespace(suffix: String = UUID().uuidString) -> String
    {
        return "com.uu.tests.keystore.\(suffix)"
    }

    static func makeAlias(namespace: String? = nil) -> String
    {
        let base = namespace ?? makeNamespace()
        return "\(base).alias-\(UUID().uuidString)"
    }

    static func qualifiedAlias(namespace: String, name: String) -> String
    {
        return "\(namespace).\(name)"
    }

    static func defaultAlgorithm() -> SecKeyAlgorithm
    {
        return .eciesEncryptionStandardVariableIVX963SHA256AESGCM
    }

    static func isSecureEnclaveBacked(_ privateKey: SecKey) -> Bool
    {
        guard let attributes = SecKeyCopyAttributes(privateKey) as? [String: Any],
              let tokenID = attributes[kSecAttrTokenID as String] as? String
        else
        {
            return false
        }

        return tokenID == (kSecAttrTokenIDSecureEnclave as String)
    }

    static func isPrivateKeyExportBlocked(_ privateKey: SecKey) -> Bool
    {
        var error: Unmanaged<CFError>?
        return SecKeyCopyExternalRepresentation(privateKey, &error) == nil
    }

    static func supportsAlgorithm(_ privateKey: SecKey, algorithm: SecKeyAlgorithm) -> Bool
    {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else
        {
            return false
        }

        return SecKeyIsAlgorithmSupported(publicKey, .encrypt, algorithm)
            && SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm)
    }

    static func eciesRoundTrip(
        privateKey: SecKey,
        plaintext: Data,
        algorithm: SecKeyAlgorithm = defaultAlgorithm()) throws -> Data
    {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else
        {
            throw KeyStoreTestError.missingPublicKey
        }

        var error: Unmanaged<CFError>?
        guard let ciphertext = SecKeyCreateEncryptedData(
            publicKey,
            algorithm,
            plaintext as CFData,
            &error) as Data?
        else
        {
            throw error?.takeRetainedValue() ?? KeyStoreTestError.encryptionFailed
        }

        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            algorithm,
            ciphertext as CFData,
            &error) as Data?
        else
        {
            throw error?.takeRetainedValue() ?? KeyStoreTestError.decryptionFailed
        }

        return decrypted
    }

    static func deleteKey(alias: String, keySizeBits: Int = 256)
    {
        let tag = alias.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: keySizeBits,
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Returns whether the current process can persist keys in the Keychain.
    ///
    /// ``swift test`` on macOS often lacks keychain entitlements (`errSecMissingEntitlement` / -34018).
    /// Hosted integration tests (Xcode test host) typically succeed.
    static func isKeychainAccessible() async -> Bool
    {
        let alias = makeAlias()
        let store = UUKeyStore(requireSecureEnclave: false)

        switch await store.loadKey(alias: alias)
        {
            case .success:
                _ = await store.deleteKey(alias: alias)
                return true

            case .failure(.missingEntitlement):
                return false

            case .failure(.keyGenerationFailed(let underlying))
                where (underlying as NSError?)?.code == Int(errSecMissingEntitlement):
                return false

            default:
                return false
        }
    }
}

enum KeyStoreTestError: Error
{
    case missingPublicKey
    case encryptionFailed
    case decryptionFailed
}

#endif
