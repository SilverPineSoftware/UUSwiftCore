//
//  KeychainTestSupport.swift
//  UUSwiftCore
//

#if os(iOS) || os(macOS)

import Foundation

enum KeychainTestSupport
{
    static let sharedAccessGroupSuffix = "com.silverpine.uu.core.test.shared"

    private static let infoPlistKey = "UUKeychainTestSharedAccessGroup"

    /// Returns the fully qualified shared access group published by ``LibraryConnectedTestHost``.
    ///
    /// Hosted integration tests run inside the test host process, so this reads
    /// `UUKeychainTestSharedAccessGroup` from the host app's Info.plist.
    static func entitledAccessGroup(
        suffix: String = sharedAccessGroupSuffix) -> String?
    {
        guard let group = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
              !group.isEmpty,
              group.hasSuffix(suffix)
        else
        {
            return nil
        }

        return group
    }

    /// Returns the app's default keychain access group (`TeamID.BundleIdentifier`).
    ///
    /// Keychain queries that omit ``kSecAttrAccessGroup`` search every entitled group, so
    /// isolation tests must compare two explicit groups instead of using `nil`.
    static func defaultAccessGroup() -> String?
    {
        guard let sharedGroup = entitledAccessGroup(),
              let bundleIdentifier = Bundle.main.bundleIdentifier,
              !bundleIdentifier.isEmpty,
              sharedGroup.hasSuffix(sharedAccessGroupSuffix)
        else
        {
            return nil
        }

        let prefix = String(sharedGroup.dropLast(sharedAccessGroupSuffix.count))

        guard !prefix.isEmpty else
        {
            return nil
        }

        return prefix + bundleIdentifier
    }
}

#endif
