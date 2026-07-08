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
public enum UUJwtConstants: Sendable
{
    /// JOSE header parameter names (RFC 7515 / RFC 7516).
    public enum Header: Sendable
    {
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
    public enum Claim: Sendable
    {
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
    ///
    /// - Parameter count: The number of dot-separated segments that were found.
    case invalidPartCount(Int)

    /// A segment between dots was empty.
    ///
    /// - Parameter index: Zero-based index of the empty segment.
    case emptyPart(Int)

    /// A segment was not valid Base64URL.
    ///
    /// - Parameter part: Zero-based index of the segment that failed to decode.
    case invalidBase64(part: Int)

    /// A segment decoded successfully but was not a JSON object.
    ///
    /// - Parameter part: Zero-based index of the segment that was not a JSON object.
    case invalidJson(part: Int)

    /// A required JOSE header field was absent or not a non-empty string.
    ///
    /// - Parameter field: Header parameter name that was missing or invalid (for example `alg` or `enc`).
    case missingRequiredHeaderField(String)
}

/// Localized descriptions for ``UUJwtError`` cases.
extension UUJwtError: LocalizedError
{
    /// A human-readable description of the JWT parsing failure.
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

/// A sendable representation of JSON values decoded from JWT headers and claims.
public enum UUJsonValue: Equatable, Sendable
{
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: UUJsonValue])
    case array([UUJsonValue])
    case null

    public var stringValue: String?
    {
        guard case .string(let value) = self else
        {
            return nil
        }

        return value
    }

    public var doubleValue: Double?
    {
        guard case .number(let value) = self else
        {
            return nil
        }

        return value
    }

    public var boolValue: Bool?
    {
        guard case .bool(let value) = self else
        {
            return nil
        }

        return value
    }
}

public typealias UUJsonObject = [String: UUJsonValue]

// MARK: - Parsed token

/// A compact JSON Web Token, either signed (JWS) or encrypted (JWE).
///
/// Use ``parse(_:)`` to parse compact serialization, then switch on ``signed(_:)`` or
/// ``encrypted(_:)``. Conforms to ``CustomStringConvertible`` and forwards ``description``
/// to the wrapped token.
public enum UUJsonWebToken: Sendable
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
///
/// Conforms to ``CustomStringConvertible``; see ``description`` for the logging format.
public struct UUSignedJsonWebToken: Sendable
{
    /// Original compact serialization used to create this value.
    public let compactSerialization: String

    /// Decoded JOSE header (for example `alg`, `typ`, `kid`).
    public let header: UUJsonObject

    /// Decoded payload claims. Only JSON object payloads are supported.
    public let payload: UUJsonObject

    /// Decoded signature bytes.
    public let signature: Data

    /// Creates a signed token from already-decoded parts.
    ///
    /// - Parameters:
    ///   - compactSerialization: Original compact JWS string used to produce this value.
    ///   - header: Decoded JOSE header object.
    ///   - payload: Decoded payload claims object.
    ///   - signature: Decoded signature bytes.
    public init(
        compactSerialization: String,
        header: UUJsonObject,
        payload: UUJsonObject,
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
        header[UUJwtConstants.Header.algorithm]?.stringValue
    }

    /// `typ` header value when present.
    public var type: String?
    {
        header[UUJwtConstants.Header.type]?.stringValue
    }

    /// `sub` claim when present.
    public var subject: String?
    {
        payload[UUJwtConstants.Claim.subject]?.stringValue
    }

    /// `iss` claim when present.
    public var issuer: String?
    {
        payload[UUJwtConstants.Claim.issuer]?.stringValue
    }

    /// `aud` claim when present (string audience only).
    public var audience: String?
    {
        payload[UUJwtConstants.Claim.audience]?.stringValue
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

    /// `nbf` claim as a ``Date`` when present.
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

        let header: UUJsonObject
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

        let payload: UUJsonObject
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
///
/// Conforms to ``CustomStringConvertible``; see ``description`` for the logging format.
public struct UUEncryptedJsonWebToken: Sendable
{
    /// Original compact serialization used to create this value.
    public let compactSerialization: String

    /// Decoded protected header (for example `alg`, `enc`, `kid`).
    public let protectedHeader: UUJsonObject

    /// Encrypted content encryption key (CEK).
    public let encryptedKey: Data

    /// Initialization vector used by the content cipher.
    public let iv: Data

    /// Encrypted ciphertext.
    public let ciphertext: Data

    /// Authentication tag from the content cipher (for example AES-GCM).
    public let authTag: Data

    /// Creates an encrypted token from already-decoded parts.
    ///
    /// - Parameters:
    ///   - compactSerialization: Original compact JWE string used to produce this value.
    ///   - protectedHeader: Decoded protected header object.
    ///   - encryptedKey: Encrypted content encryption key bytes.
    ///   - iv: Initialization vector bytes.
    ///   - ciphertext: Encrypted ciphertext bytes.
    ///   - authTag: Authentication tag bytes.
    public init(
        compactSerialization: String,
        protectedHeader: UUJsonObject,
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
        protectedHeader[UUJwtConstants.Header.algorithm]?.stringValue
    }

    /// `enc` protected-header value when present.
    public var encryption: String?
    {
        protectedHeader[UUJwtConstants.Header.encryption]?.stringValue
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

        let protectedHeader: UUJsonObject
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
        part index: Int) -> Result<UUJsonObject, UUJwtError>
    {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = json as? [String: Any],
              let jsonObject = jsonObject(from: dictionary)
        else
        {
            return .failure(.invalidJson(part: index))
        }

        return .success(jsonObject)
    }

    static func requiredHeaderString(
        _ header: UUJsonObject,
        key: String) -> Result<String, UUJwtError>
    {
        guard let value = header[key]?.stringValue,
              !value.isEmpty
        else
        {
            return .failure(.missingRequiredHeaderField(key))
        }

        return .success(value)
    }

    static func date(fromNumericDateClaim value: UUJsonValue?) -> Date?
    {
        guard let seconds = value?.doubleValue else
        {
            return nil
        }

        return Date(timeIntervalSince1970: seconds)
    }

    static func jsonObject(from dictionary: [String: Any]) -> UUJsonObject?
    {
        var object: UUJsonObject = [:]

        for (key, value) in dictionary
        {
            guard let jsonValue = jsonValue(from: value) else
            {
                return nil
            }

            object[key] = jsonValue
        }

        return object
    }

    static func jsonArray(from array: [Any]) -> [UUJsonValue]?
    {
        var values: [UUJsonValue] = []

        for value in array
        {
            guard let jsonValue = jsonValue(from: value) else
            {
                return nil
            }

            values.append(jsonValue)
        }

        return values
    }

    static func jsonValue(from value: Any) -> UUJsonValue?
    {
        switch value
        {
            case _ as NSNull:
                return .null

            case let value as Bool:
                return .bool(value)

            case let value as String:
                return .string(value)

            case let value as NSNumber:
                return .number(value.doubleValue)

            case let value as [String: Any]:
                guard let object = jsonObject(from: value) else
                {
                    return nil
                }

                return .object(object)

            case let value as [Any]:
                guard let array = jsonArray(from: value) else
                {
                    return nil
                }

                return .array(array)

            default:
                return nil
        }
    }
}

// MARK: - Header helpers

/// JOSE header helpers for decoded JWT header dictionaries.
public extension Dictionary where Key == String, Value == UUJsonValue
{
    /// Returns the `kid` (key ID) JOSE header value when present.
    ///
    /// - Returns: The key identifier string, or `nil` when `kid` is absent or not a string.
    func uuJwtKeyID() -> String?
    {
        self[UUJwtConstants.Header.keyID]?.stringValue
    }
}

public extension UUSignedJsonWebToken
{
    /// `kid` header value when present.
    ///
    /// Same value as calling ``uuJwtKeyID()`` on ``header``.
    var keyID: String?
    {
        header.uuJwtKeyID()
    }
}

public extension UUEncryptedJsonWebToken
{
    /// `kid` protected-header value when present.
    ///
    /// Same value as calling ``uuJwtKeyID()`` on ``protectedHeader``.
    var keyID: String?
    {
        protectedHeader.uuJwtKeyID()
    }
}

// MARK: - CustomStringConvertible

extension UUJsonWebToken: CustomStringConvertible
{
    /// A logging-friendly summary that forwards to the wrapped signed or encrypted token.
    public var description: String
    {
        switch self
        {
            case .signed(let token):
                return token.description

            case .encrypted(let token):
                return token.description
        }
    }
}

extension UUSignedJsonWebToken: CustomStringConvertible
{
    /// A logging-friendly summary of a signed token.
    ///
    /// Includes the token kind (`JWS`), present header and claim accessors, and decoded
    /// signature byte count. Omits absent fields and does not include compact serialization
    /// or raw payload bytes.
    ///
    /// Example: `JWS, alg=HS256, typ=JWT, sub=1234567890, signatureBytes=32`
    public var description: String
    {
        var components = ["JWS"]

        if let algorithm
        {
            components.append("alg=\(algorithm)")
        }

        if let type
        {
            components.append("typ=\(type)")
        }

        if let keyID
        {
            components.append("kid=\(keyID)")
        }

        if let subject
        {
            components.append("sub=\(subject)")
        }

        if let issuer
        {
            components.append("iss=\(issuer)")
        }

        if let audience
        {
            components.append("aud=\(audience)")
        }

        components.append("signatureBytes=\(signature.count)")

        return components.joined(separator: ", ")
    }
}

extension UUEncryptedJsonWebToken: CustomStringConvertible
{
    /// A logging-friendly summary of an encrypted token.
    ///
    /// Includes the token kind (`JWE`), present protected-header fields, and decoded binary
    /// part byte counts. Omits absent fields and does not include compact serialization
    /// or ciphertext bytes.
    ///
    /// Example: `JWE, alg=RSA-OAEP, enc=A256GCM, encryptedKeyBytes=3, ivBytes=3, ciphertextBytes=14, authTagBytes=3`
    public var description: String
    {
        var components = ["JWE"]

        if let algorithm
        {
            components.append("alg=\(algorithm)")
        }

        if let encryption
        {
            components.append("enc=\(encryption)")
        }

        if let keyID
        {
            components.append("kid=\(keyID)")
        }

        components.append("encryptedKeyBytes=\(encryptedKey.count)")
        components.append("ivBytes=\(iv.count)")
        components.append("ciphertextBytes=\(ciphertext.count)")
        components.append("authTagBytes=\(authTag.count)")

        return components.joined(separator: ", ")
    }
}
