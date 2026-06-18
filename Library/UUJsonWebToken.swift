//
//  UUJsonWebToken.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/17/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Structural parsing for JSON Web Tokens in compact serialization form.
//
//  ``UUJsonWebToken`` is the entry point for parsing either a signed token (JWS,
//  three parts) or an encrypted token (JWE, five parts). Parsing validates
//  compact layout, Base64URL segments, JSON headers, and required header fields.
//  Cryptographic signature verification and decryption are intentionally out of
//  scope.
//

import Foundation

// MARK: - Constants

/// Standard JSON Web Token field names used by ``UUJsonWebToken`` and related APIs.
public struct UUJwtConstants
{
    private init()
    {
    }

    /// JOSE header parameter names (RFC 7515 / RFC 7516).
    public struct Header
    {
        private init()
        {
        }

        /// `alg` — cryptographic algorithm or key management algorithm.
        public static let algorithm = "alg"

        /// `typ` — media type (often `JWT`).
        public static let type = "typ"

        /// `enc` — content encryption algorithm (JWE).
        public static let encryption = "enc"

        /// `kid` — key identifier.
        public static let keyID = "kid"
    }

    /// Registered JWT claims (RFC 7519).
    public struct Claim
    {
        private init()
        {
        }

        /// `sub` — subject.
        public static let subject = "sub"

        /// `iss` — issuer.
        public static let issuer = "iss"

        /// `aud` — audience.
        public static let audience = "aud"

        /// `exp` — expiration time.
        public static let expiration = "exp"

        /// `iat` — issued at.
        public static let issuedAt = "iat"

        /// `nbf` — not before.
        public static let notBefore = "nbf"
    }
}

// MARK: - Errors

/// Errors produced by JWT operations in UUSwiftCore.
public enum UUJwtError: Error, Equatable, Sendable
{
    /// The token does not contain exactly three (JWS) or five (JWE) segments.
    case invalidPartCount(Int)

    /// A segment between dots was empty.
    case emptyPart(Int)

    /// A segment was not valid Base64URL.
    case invalidBase64(part: Int)

    /// A segment decoded successfully but was not a JSON object.
    case invalidJson(part: Int)

    /// A required JOSE header field was absent or not a non-empty string.
    case missingRequiredHeaderField(String)
}

extension UUJwtError: LocalizedError
{
    public var errorDescription: String?
    {
        switch self
        {
            case .invalidPartCount(let count):
                return "JWT compact serialization requires 3 (JWS) or 5 (JWE) parts; found \(count)."

            case .emptyPart(let index):
                return "JWT part \(index) is empty."

            case .invalidBase64(let part):
                return "JWT part \(part) is not valid Base64URL."

            case .invalidJson(let part):
                return "JWT part \(part) is not valid JSON object."

            case .missingRequiredHeaderField(let field):
                return "JWT header is missing required field '\(field)'."
        }
    }
}

// MARK: - Parsed token

/// A compact JSON Web Token, either signed (JWS) or encrypted (JWE).
public enum UUJsonWebToken
{
    /// A signed token (JWS) with three Base64URL-encoded parts.
    case signed(UUSignedJsonWebToken)

    /// An encrypted token (JWE) with five Base64URL-encoded parts.
    case encrypted(UUEncryptedJsonWebToken)

    /// Parses a compact JWT string into a signed or encrypted token.
    ///
    /// Leading and trailing whitespace is trimmed.
    ///
    /// - Parameter string: Compact serialization (`header.payload.signature` or
    ///   `protectedHeader.encryptedKey.iv.ciphertext.authTag`).
    /// - Returns: `.success` with the parsed token, or `.failure` with
    ///   ``UUJwtError`` when the string is not structurally valid.
    public static func parse(_ string: String) -> Result<UUJsonWebToken, UUJwtError>
    {
        let (compactSerialization, parts) = UUJwtParser.parts(from: string)

        switch parts.count
        {
            case 3:
                return UUSignedJsonWebToken.parse(
                    parts: parts,
                    compactSerialization: compactSerialization)
                    .map(UUJsonWebToken.signed)

            case 5:
                return UUEncryptedJsonWebToken.parse(
                    parts: parts,
                    compactSerialization: compactSerialization)
                    .map(UUJsonWebToken.encrypted)

            default:
                return .failure(.invalidPartCount(parts.count))
        }
    }
}

// MARK: - JWS

/// A signed JSON Web Token (JWS) parsed from compact serialization.
///
/// The header and payload are JSON objects. The signature is the decoded binary
/// signature bytes. Use ``algorithm`` and payload claim accessors for logging
/// and inspection without verifying the signature.
public struct UUSignedJsonWebToken
{
    /// Original compact serialization used to create this value.
    public let compactSerialization: String

    /// Decoded JOSE header (for example `alg`, `typ`, `kid`).
    public let header: [AnyHashable: Any]

    /// Decoded payload claims. Only JSON object payloads are supported.
    public let payload: [AnyHashable: Any]

    /// Decoded signature bytes.
    public let signature: Data

    /// Creates a signed token from already-decoded parts.
    public init(
        compactSerialization: String,
        header: [AnyHashable: Any],
        payload: [AnyHashable: Any],
        signature: Data)
    {
        self.compactSerialization = compactSerialization
        self.header = header
        self.payload = payload
        self.signature = signature
    }

    /// Parses a compact JWS string.
    ///
    /// - Parameter string: Compact serialization with three dot-separated parts.
    /// - Returns: `.success` with the parsed signed token, or `.failure` with
    ///   ``UUJwtError`` when parsing fails.
    public static func parse(_ string: String) -> Result<UUSignedJsonWebToken, UUJwtError>
    {
        let (compactSerialization, parts) = UUJwtParser.parts(from: string)

        guard parts.count == 3 else
        {
            return .failure(.invalidPartCount(parts.count))
        }

        return parse(parts: parts, compactSerialization: compactSerialization)
    }

    /// `alg` header value when present.
    public var algorithm: String?
    {
        header[UUJwtConstants.Header.algorithm] as? String
    }

    /// `typ` header value when present.
    public var type: String?
    {
        header[UUJwtConstants.Header.type] as? String
    }

    /// `sub` claim when present.
    public var subject: String?
    {
        payload[UUJwtConstants.Claim.subject] as? String
    }

    /// `iss` claim when present.
    public var issuer: String?
    {
        payload[UUJwtConstants.Claim.issuer] as? String
    }

    /// `aud` claim when present (string audience only).
    public var audience: String?
    {
        payload[UUJwtConstants.Claim.audience] as? String
    }

    /// `exp` claim as a ``Date`` when present.
    public var expiration: Date?
    {
        UUJwtParser.date(fromNumericDateClaim: payload[UUJwtConstants.Claim.expiration])
    }

    /// `iat` claim as a ``Date`` when present.
    public var issuedAt: Date?
    {
        UUJwtParser.date(fromNumericDateClaim: payload[UUJwtConstants.Claim.issuedAt])
    }

    /// `nbf` claim when present.
    public var notBefore: Date?
    {
        UUJwtParser.date(fromNumericDateClaim: payload[UUJwtConstants.Claim.notBefore])
    }

    fileprivate static func parse(
        parts: [String],
        compactSerialization: String) -> Result<UUSignedJsonWebToken, UUJwtError>
    {
        if case .failure(let error) = UUJwtParser.requireNonEmptyParts(parts)
        {
            return .failure(error)
        }

        let headerData: Data
        switch UUJwtParser.decodeBase64Part(parts[0], part: 0)
        {
            case .success(let data):
                headerData = data

            case .failure(let error):
                return .failure(error)
        }

        let header: [AnyHashable: Any]
        switch UUJwtParser.decodeJsonObject(from: headerData, part: 0)
        {
            case .success(let json):
                header = json

            case .failure(let error):
                return .failure(error)
        }

        switch UUJwtParser.requiredHeaderString(header, key: UUJwtConstants.Header.algorithm)
        {
            case .success:
                break

            case .failure(let error):
                return .failure(error)
        }

        let payloadData: Data
        switch UUJwtParser.decodeBase64Part(parts[1], part: 1)
        {
            case .success(let data):
                payloadData = data

            case .failure(let error):
                return .failure(error)
        }

        let payload: [AnyHashable: Any]
        switch UUJwtParser.decodeJsonObject(from: payloadData, part: 1)
        {
            case .success(let json):
                payload = json

            case .failure(let error):
                return .failure(error)
        }

        let signature: Data
        switch UUJwtParser.decodeBase64Part(parts[2], part: 2)
        {
            case .success(let data):
                signature = data

            case .failure(let error):
                return .failure(error)
        }

        return .success(UUSignedJsonWebToken(
            compactSerialization: compactSerialization,
            header: header,
            payload: payload,
            signature: signature))
    }
}

// MARK: - JWE

/// An encrypted JSON Web Token (JWE) parsed from compact serialization.
///
/// The protected header is a JSON object. The remaining parts are opaque binary
/// blobs used for key management and content encryption.
public struct UUEncryptedJsonWebToken
{
    /// Original compact serialization used to create this value.
    public let compactSerialization: String

    /// Decoded protected header (for example `alg`, `enc`, `kid`).
    public let protectedHeader: [AnyHashable: Any]

    /// Encrypted content encryption key (CEK).
    public let encryptedKey: Data

    /// Initialization vector used by the content cipher.
    public let iv: Data

    /// Encrypted ciphertext.
    public let ciphertext: Data

    /// Authentication tag from the content cipher (for example AES-GCM).
    public let authTag: Data

    /// Creates an encrypted token from already-decoded parts.
    public init(
        compactSerialization: String,
        protectedHeader: [AnyHashable: Any],
        encryptedKey: Data,
        iv: Data,
        ciphertext: Data,
        authTag: Data)
    {
        self.compactSerialization = compactSerialization
        self.protectedHeader = protectedHeader
        self.encryptedKey = encryptedKey
        self.iv = iv
        self.ciphertext = ciphertext
        self.authTag = authTag
    }

    /// Parses a compact JWE string.
    ///
    /// - Parameter string: Compact serialization with five dot-separated parts.
    /// - Returns: `.success` with the parsed encrypted token, or `.failure` with
    ///   ``UUJwtError`` when parsing fails.
    public static func parse(_ string: String) -> Result<UUEncryptedJsonWebToken, UUJwtError>
    {
        let (compactSerialization, parts) = UUJwtParser.parts(from: string)

        guard parts.count == 5 else
        {
            return .failure(.invalidPartCount(parts.count))
        }

        return parse(parts: parts, compactSerialization: compactSerialization)
    }

    /// `alg` protected-header value when present.
    public var algorithm: String?
    {
        protectedHeader[UUJwtConstants.Header.algorithm] as? String
    }

    /// `enc` protected-header value when present.
    public var encryption: String?
    {
        protectedHeader[UUJwtConstants.Header.encryption] as? String
    }

    fileprivate static func parse(
        parts: [String],
        compactSerialization: String) -> Result<UUEncryptedJsonWebToken, UUJwtError>
    {
        // The encrypted-key segment may be empty for direct key agreement (`dir`).
        if case .failure(let error) = UUJwtParser.requireNonEmptyParts(parts, except: [1])
        {
            return .failure(error)
        }

        let headerData: Data
        switch UUJwtParser.decodeBase64Part(parts[0], part: 0)
        {
            case .success(let data):
                headerData = data

            case .failure(let error):
                return .failure(error)
        }

        let protectedHeader: [AnyHashable: Any]
        switch UUJwtParser.decodeJsonObject(from: headerData, part: 0)
        {
            case .success(let json):
                protectedHeader = json

            case .failure(let error):
                return .failure(error)
        }

        switch UUJwtParser.requiredHeaderString(protectedHeader, key: UUJwtConstants.Header.algorithm)
        {
            case .success:
                break

            case .failure(let error):
                return .failure(error)
        }

        switch UUJwtParser.requiredHeaderString(protectedHeader, key: UUJwtConstants.Header.encryption)
        {
            case .success:
                break

            case .failure(let error):
                return .failure(error)
        }

        let encryptedKey: Data
        switch UUJwtParser.decodeBase64Part(parts[1], part: 1, allowsEmpty: true)
        {
            case .success(let data):
                encryptedKey = data

            case .failure(let error):
                return .failure(error)
        }

        let iv: Data
        switch UUJwtParser.decodeBase64Part(parts[2], part: 2)
        {
            case .success(let data):
                iv = data

            case .failure(let error):
                return .failure(error)
        }

        let ciphertext: Data
        switch UUJwtParser.decodeBase64Part(parts[3], part: 3)
        {
            case .success(let data):
                ciphertext = data

            case .failure(let error):
                return .failure(error)
        }

        let authTag: Data
        switch UUJwtParser.decodeBase64Part(parts[4], part: 4)
        {
            case .success(let data):
                authTag = data

            case .failure(let error):
                return .failure(error)
        }

        return .success(UUEncryptedJsonWebToken(
            compactSerialization: compactSerialization,
            protectedHeader: protectedHeader,
            encryptedKey: encryptedKey,
            iv: iv,
            ciphertext: ciphertext,
            authTag: authTag))
    }
}

// MARK: - Parser support

private enum UUJwtParser
{
    static func parts(from string: String) -> (compactSerialization: String, parts: [String])
    {
        let compactSerialization = normalizedToken(from: string)
        let parts = compactSerialization
            .split(separator: ".", omittingEmptySubsequences: false)
            .map(String.init)

        return (compactSerialization, parts)
    }

    static func requireNonEmptyParts(
        _ parts: [String],
        except indices: Set<Int> = []) -> Result<Void, UUJwtError>
    {
        for (index, part) in parts.enumerated() where part.isEmpty && !indices.contains(index)
        {
            return .failure(.emptyPart(index))
        }

        return .success(())
    }

    static func normalizedToken(from string: String) -> String
    {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeBase64Part(
        _ part: String,
        part index: Int,
        allowsEmpty: Bool = false) -> Result<Data, UUJwtError>
    {
        if part.isEmpty
        {
            guard allowsEmpty else
            {
                return .failure(.emptyPart(index))
            }

            return .success(Data())
        }

        guard let data = part.uuBase64UrlDecode() else
        {
            return .failure(.invalidBase64(part: index))
        }

        return .success(data)
    }

    static func decodeJsonObject(
        from data: Data,
        part index: Int) -> Result<[AnyHashable: Any], UUJwtError>
    {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = json as? [AnyHashable: Any]
        else
        {
            return .failure(.invalidJson(part: index))
        }

        return .success(dictionary)
    }

    static func requiredHeaderString(
        _ header: [AnyHashable: Any],
        key: String) -> Result<String, UUJwtError>
    {
        guard let value = header[key] as? String,
              !value.isEmpty
        else
        {
            return .failure(.missingRequiredHeaderField(key))
        }

        return .success(value)
    }

    static func date(fromNumericDateClaim value: Any?) -> Date?
    {
        let seconds: TimeInterval?

        switch value
        {
            case let number as NSNumber:
                seconds = number.doubleValue

            case let number as Double:
                seconds = number

            case let number as Int:
                seconds = TimeInterval(number)

            default:
                seconds = nil
        }

        guard let seconds else
        {
            return nil
        }

        return Date(timeIntervalSince1970: seconds)
    }
}

// MARK: - Header helpers

public extension Dictionary where Key == AnyHashable, Value == Any
{
    /// Returns the `kid` (key ID) JOSE header value when present.
    func uuJwtKeyID() -> String?
    {
        self[UUJwtConstants.Header.keyID] as? String
    }
}

public extension UUSignedJsonWebToken
{
    /// `kid` header value when present.
    var keyID: String?
    {
        header.uuJwtKeyID()
    }
}

public extension UUEncryptedJsonWebToken
{
    /// `kid` protected-header value when present.
    var keyID: String?
    {
        protectedHeader.uuJwtKeyID()
    }
}
