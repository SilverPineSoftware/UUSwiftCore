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

    /// Returns the fully qualified access group published by ``LibraryIntegrationTestHost``.
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
}

#endif
