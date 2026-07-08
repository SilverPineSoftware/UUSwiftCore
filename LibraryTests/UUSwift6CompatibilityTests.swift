//
//  UUSwift6CompatibilityTests.swift
//  UUSwiftCore
//

import XCTest
@testable import UUSwiftCore

final class UUSwift6CompatibilityTests: XCTestCase
{
    func test_publicConcurrencyValueTypes_areSendable()
    {
        requireSendable(UUJwtConstants.self)
        requireSendable(UUJwtConstants.Header.self)
        requireSendable(UUJwtConstants.Claim.self)
        requireSendable(UUJwtError.self)
        requireSendable(UUJsonValue.self)
        requireSendable(UUJsonWebToken.self)
        requireSendable(UUSignedJsonWebToken.self)
        requireSendable(UUEncryptedJsonWebToken.self)

        #if os(iOS) || os(macOS)
        requireSendable(UUKeychainAccessLevel.self)
        requireSendable(UUKeychainError.self)
        requireSendable(UUKeyStoreError.self)
        requireSendable(UUCryptoError.self)
        requireSendable(UUDeviceCrypto.self)
        requireSendable(UUDeviceKeyStore.self)
        #endif
    }

    private func requireSendable<T: Sendable>(_ type: T.Type)
    {
    }
}
