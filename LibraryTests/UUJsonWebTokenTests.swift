//
//  UUJsonWebTokenTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/17/26.
//

import XCTest
@testable import UUSwiftCore

// MARK: - Test vectors

private enum JwtTestVectors
{
    // jwt.io HS256 example (signature not verified here).
    static let signedToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
        + "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ."
        + "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

    static let encryptedToken: String = {
        let header = base64URL(json: [
            UUJwtConstants.Header.algorithm: "RSA-OAEP",
            UUJwtConstants.Header.encryption: "A256GCM",
        ])
        let encryptedKey = base64URL(data: Data([0x01, 0x02, 0x03]))
        let iv = base64URL(data: Data([0x0A, 0x0B, 0x0C]))
        let ciphertext = base64URL(data: Data("secret-payload".utf8))
        let authTag = base64URL(data: Data([0xAA, 0xBB, 0xCC]))
        return [header, encryptedKey, iv, ciphertext, authTag].joined(separator: ".")
    }()

    static func base64URL(json object: [String: Any]) -> String
    {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [])
        return base64URL(data: data)
    }

    static func base64URL(data: Data) -> String
    {
        data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func signedToken(
        header: [String: Any],
        payload: [String: Any],
        signature: Data = Data([0xDE, 0xAD, 0xBE, 0xEF])) -> String
    {
        [
            base64URL(json: header),
            base64URL(json: payload),
            base64URL(data: signature),
        ].joined(separator: ".")
    }
}

// MARK: - Assertions

private func XCTAssertParseFailure<T>(
    _ result: Result<T, UUJwtError>,
    _ expected: UUJwtError,
    file: StaticString = #filePath,
    line: UInt = #line)
{
    guard case .failure(let error) = result else
    {
        XCTFail("Expected failure \(expected), got success", file: file, line: line)
        return
    }

    XCTAssertEqual(error, expected, file: file, line: line)
}

// MARK: - Parse errors

final class UUJwtErrorTests: XCTestCase
{
    func test_errorDescription_isNonEmptyForAllCases()
    {
        let errors: [UUJwtError] = [
            .invalidPartCount(2),
            .emptyPart(1),
            .invalidBase64(part: 0),
            .invalidJson(part: 1),
            .missingRequiredHeaderField(UUJwtConstants.Header.algorithm),
        ]

        for error in errors
        {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Missing description for \(error)")
        }
    }
}

// MARK: - Signed token

final class UUSignedJsonWebTokenTests: XCTestCase
{
    func test_parse_decodesKnownToken()
    {
        switch UUSignedJsonWebToken.parse(JwtTestVectors.signedToken)
        {
            case .success(let token):
                XCTAssertEqual(token.compactSerialization, JwtTestVectors.signedToken)
                XCTAssertEqual(token.algorithm, "HS256")
                XCTAssertEqual(token.type, "JWT")
                XCTAssertEqual(token.subject, "1234567890")
                XCTAssertEqual(token.payload["name"] as? String, "John Doe")
                XCTAssertEqual(token.issuedAt, Date(timeIntervalSince1970: 1_516_239_022))
                XCTAssertFalse(token.signature.isEmpty)

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_parse_get_returnsSuccessValue() throws
    {
        let token = try UUSignedJsonWebToken.parse(JwtTestVectors.signedToken).get()
        XCTAssertEqual(token.algorithm, "HS256")
    }

    func test_parse_get_rethrowsFailure() throws
    {
        XCTAssertThrowsError(try UUSignedJsonWebToken.parse("only.two").get()) { error in
            XCTAssertEqual(error as? UUJwtError, .invalidPartCount(2))
        }
    }

    func test_parse_trimsWhitespace()
    {
        switch UUSignedJsonWebToken.parse("  \(JwtTestVectors.signedToken) \n")
        {
            case .success(let token):
                XCTAssertEqual(token.compactSerialization, JwtTestVectors.signedToken)

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_parse_returnsFailureForBearerPrefix()
    {
        XCTAssertParseFailure(
            UUSignedJsonWebToken.parse("Bearer \(JwtTestVectors.signedToken)"),
            .invalidBase64(part: 0))
    }

    func test_parse_returnsFailureForInvalidPartCount()
    {
        XCTAssertParseFailure(UUSignedJsonWebToken.parse("only.two"), .invalidPartCount(2))
        XCTAssertParseFailure(
            UUSignedJsonWebToken.parse(JwtTestVectors.encryptedToken),
            .invalidPartCount(5))
    }

    func test_parse_returnsFailureForEmptyPart()
    {
        XCTAssertParseFailure(UUSignedJsonWebToken.parse(".a.b"), .emptyPart(0))
        XCTAssertParseFailure(UUSignedJsonWebToken.parse("a..c"), .emptyPart(1))
        XCTAssertParseFailure(UUSignedJsonWebToken.parse(".a.b.c"), .invalidPartCount(4))
    }

    func test_parse_returnsFailureForInvalidBase64()
    {
        let token = "%%%." + JwtTestVectors.base64URL(json: [UUJwtConstants.Header.algorithm: "HS256"]) + ".signature"
        XCTAssertParseFailure(UUSignedJsonWebToken.parse(token), .invalidBase64(part: 0))
    }

    func test_parse_returnsFailureForInvalidHeaderJson()
    {
        let header = JwtTestVectors.base64URL(data: Data("not-json".utf8))
        let payload = JwtTestVectors.base64URL(json: [UUJwtConstants.Claim.subject: "1"])
        let signature = JwtTestVectors.base64URL(data: Data([0x01]))

        XCTAssertParseFailure(
            UUSignedJsonWebToken.parse("\(header).\(payload).\(signature)"),
            .invalidJson(part: 0))
    }

    func test_parse_returnsFailureForInvalidPayloadJson()
    {
        let header = JwtTestVectors.base64URL(json: [UUJwtConstants.Header.algorithm: "HS256"])
        let payload = JwtTestVectors.base64URL(data: Data("[1,2,3]".utf8))
        let signature = JwtTestVectors.base64URL(data: Data([0x01]))

        XCTAssertParseFailure(
            UUSignedJsonWebToken.parse("\(header).\(payload).\(signature)"),
            .invalidJson(part: 1))
    }

    func test_parse_returnsFailureWhenAlgHeaderMissing()
    {
        let token = JwtTestVectors.signedToken(
            header: [UUJwtConstants.Header.type: "JWT"],
            payload: [UUJwtConstants.Claim.subject: "1"])

        XCTAssertParseFailure(
            UUSignedJsonWebToken.parse(token),
            .missingRequiredHeaderField(UUJwtConstants.Header.algorithm))
    }

    func test_parse_returnsFailureWhenAlgHeaderEmpty()
    {
        let token = JwtTestVectors.signedToken(
            header: [UUJwtConstants.Header.algorithm: ""],
            payload: [UUJwtConstants.Claim.subject: "1"])

        XCTAssertParseFailure(
            UUSignedJsonWebToken.parse(token),
            .missingRequiredHeaderField(UUJwtConstants.Header.algorithm))
    }

    func test_claimAccessors_returnNilWhenAbsent()
    {
        switch UUSignedJsonWebToken.parse(
            JwtTestVectors.signedToken(header: [UUJwtConstants.Header.algorithm: "none"], payload: [:]))
        {
            case .success(let token):
                XCTAssertEqual(token.algorithm, "none")
                XCTAssertNil(token.type)
                XCTAssertNil(token.subject)
                XCTAssertNil(token.issuer)
                XCTAssertNil(token.audience)
                XCTAssertNil(token.expiration)
                XCTAssertNil(token.issuedAt)
                XCTAssertNil(token.notBefore)

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_claimAccessors_parseNumericDatesFromNSNumber()
    {
        switch UUSignedJsonWebToken.parse(
            JwtTestVectors.signedToken(
                header: [UUJwtConstants.Header.algorithm: "HS256"],
                payload: [
                    UUJwtConstants.Claim.expiration: NSNumber(value: 1_700_000_000),
                    UUJwtConstants.Claim.notBefore: NSNumber(value: 1_600_000_000),
                ]))
        {
            case .success(let token):
                XCTAssertEqual(token.expiration, Date(timeIntervalSince1970: 1_700_000_000))
                XCTAssertEqual(token.notBefore, Date(timeIntervalSince1970: 1_600_000_000))

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }
}

// MARK: - Encrypted token

final class UUEncryptedJsonWebTokenTests: XCTestCase
{
    func test_parse_decodesFivePartToken()
    {
        switch UUEncryptedJsonWebToken.parse(JwtTestVectors.encryptedToken)
        {
            case .success(let token):
                XCTAssertEqual(token.compactSerialization, JwtTestVectors.encryptedToken)
                XCTAssertEqual(token.algorithm, "RSA-OAEP")
                XCTAssertEqual(token.encryption, "A256GCM")
                XCTAssertEqual(token.encryptedKey, Data([0x01, 0x02, 0x03]))
                XCTAssertEqual(token.iv, Data([0x0A, 0x0B, 0x0C]))
                XCTAssertEqual(token.ciphertext, Data("secret-payload".utf8))
                XCTAssertEqual(token.authTag, Data([0xAA, 0xBB, 0xCC]))

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_parse_trimsWhitespace()
    {
        switch UUEncryptedJsonWebToken.parse("  \(JwtTestVectors.encryptedToken)  ")
        {
            case .success(let token):
                XCTAssertEqual(token.compactSerialization, JwtTestVectors.encryptedToken)

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_parse_returnsFailureForInvalidPartCount()
    {
        XCTAssertParseFailure(
            UUEncryptedJsonWebToken.parse(JwtTestVectors.signedToken),
            .invalidPartCount(3))
    }

    func test_parse_returnsFailureWhenAlgMissing()
    {
        let header = JwtTestVectors.base64URL(json: [UUJwtConstants.Header.encryption: "A256GCM"])
        let token = [
            header,
            JwtTestVectors.base64URL(data: Data([0x01])),
            JwtTestVectors.base64URL(data: Data([0x02])),
            JwtTestVectors.base64URL(data: Data([0x03])),
            JwtTestVectors.base64URL(data: Data([0x04])),
        ].joined(separator: ".")

        XCTAssertParseFailure(
            UUEncryptedJsonWebToken.parse(token),
            .missingRequiredHeaderField(UUJwtConstants.Header.algorithm))
    }

    func test_parse_returnsFailureWhenEncMissing()
    {
        let header = JwtTestVectors.base64URL(json: [UUJwtConstants.Header.algorithm: "RSA-OAEP"])
        let token = [
            header,
            JwtTestVectors.base64URL(data: Data([0x01])),
            JwtTestVectors.base64URL(data: Data([0x02])),
            JwtTestVectors.base64URL(data: Data([0x03])),
            JwtTestVectors.base64URL(data: Data([0x04])),
        ].joined(separator: ".")

        XCTAssertParseFailure(
            UUEncryptedJsonWebToken.parse(token),
            .missingRequiredHeaderField(UUJwtConstants.Header.encryption))
    }

    func test_parse_allowsEmptyEncryptedKeySegment()
    {
        let header = JwtTestVectors.base64URL(json: [
            UUJwtConstants.Header.algorithm: "dir",
            UUJwtConstants.Header.encryption: "A256GCM",
        ])
        let token = [
            header,
            "",
            JwtTestVectors.base64URL(data: Data([0x0A])),
            JwtTestVectors.base64URL(data: Data([0x0B])),
            JwtTestVectors.base64URL(data: Data([0x0C])),
        ].joined(separator: ".")

        switch UUEncryptedJsonWebToken.parse(token)
        {
            case .success(let parsed):
                XCTAssertTrue(parsed.encryptedKey.isEmpty)

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }
}

// MARK: - Entry point

final class UUJsonWebTokenTests: XCTestCase
{
    func test_parse_returnsSignedForThreeParts()
    {
        switch UUJsonWebToken.parse(JwtTestVectors.signedToken)
        {
            case .success(.signed(let signed)):
                XCTAssertEqual(signed.algorithm, "HS256")

            case .success(.encrypted):
                XCTFail("Expected signed token")

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_parse_returnsEncryptedForFiveParts()
    {
        switch UUJsonWebToken.parse(JwtTestVectors.encryptedToken)
        {
            case .success(.encrypted(let encrypted)):
                XCTAssertEqual(encrypted.encryption, "A256GCM")

            case .success(.signed):
                XCTFail("Expected encrypted token")

            case .failure(let error):
                XCTFail("Expected success, got \(error)")
        }
    }

    func test_parse_returnsFailureForUnsupportedPartCount()
    {
        XCTAssertParseFailure(UUJsonWebToken.parse("one"), .invalidPartCount(1))
        XCTAssertParseFailure(UUJsonWebToken.parse("a.b.c.d"), .invalidPartCount(4))
    }
}
