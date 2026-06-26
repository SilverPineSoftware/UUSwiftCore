//
//  UUBase64Tests.swift
//  UUSwiftCoreTests
//
//  Created by Ryan DeVore on 6/26/26.
//

import XCTest
@testable import UUSwiftCore

final class UUBase64UrlEncodeTests: XCTestCase
{
    func test_encode_emptyData_returnsEmptyString()
    {
        XCTAssertEqual(Data().uuBase64UrlEncode(), "")
    }

    func test_encode_producesUrlSafeAlphabetWithoutPadding()
    {
        // Standard Base64 would be "Pj+//w=="; Base64URL is "Pj-__w"
        let encoded = Data([0x3E, 0x3F, 0xBF, 0xFF]).uuBase64UrlEncode()
        XCTAssertEqual(encoded, "Pj-__w")
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }

    func test_encode_singleByte()
    {
        XCTAssertEqual(Data([0xFB]).uuBase64UrlEncode(), "-w")
    }

    func test_encode_jsonHeader_matchesJwtStyle()
    {
        let header = Data("{\"alg\":\"HS256\",\"typ\":\"JWT\"}".utf8)
        XCTAssertEqual(header.uuBase64UrlEncode(), "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
    }

}


final class UUBase64UrlDecodeTests: XCTestCase
{
    func test_decode_emptyString_returnsEmptyData()
    {
        XCTAssertEqual("".uuBase64UrlDecode(), Data())
    }

    func test_decode_urlSafeVector()
    {
        let decoded = "Pj-__w".uuBase64UrlDecode()
        XCTAssertEqual(decoded, Data([0x3E, 0x3F, 0xBF, 0xFF]))
    }

    func test_decode_jwtHeaderSegment()
    {
        let decoded = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9".uuBase64UrlDecode()
        let object = try! JSONSerialization.jsonObject(with: XCTUnwrap(decoded)) as! [String: Any]
        XCTAssertEqual(object["alg"] as? String, "HS256")
        XCTAssertEqual(object["typ"] as? String, "JWT")
    }

    func test_decode_nonAlphabetCharactersAreIgnored()
    {
        // Legacy decoding uses `.ignoreUnknownCharacters`, matching JWT segment parsing behavior.
        XCTAssertNotNil("ab!!cd".uuBase64UrlDecode())
    }

    func test_decode_invalidPaddingLength_returnsNil()
    {
        XCTAssertNil("A".uuBase64UrlDecode())
    }

    func test_decode_acceptsPaddedInput()
    {
        let padded = "Pj-__w=="
        XCTAssertEqual(padded.uuBase64UrlDecode(), Data([0x3E, 0x3F, 0xBF, 0xFF]))
    }
}

final class UUBase64RoundTripTests: XCTestCase
{
    func test_roundTrip_empty()
    {
        let original = Data()
        XCTAssertEqual(original.uuBase64UrlEncode().uuBase64UrlDecode(), original)
    }

    func test_roundTrip_singleByte()
    {
        let original = Data([0x00])
        XCTAssertEqual(original.uuBase64UrlEncode().uuBase64UrlDecode(), original)
    }

    func test_roundTrip_randomPayload()
    {
        let original = Data((0..<32).map { UInt8($0) })
        XCTAssertEqual(original.uuBase64UrlEncode().uuBase64UrlDecode(), original)
    }

    func test_roundTrip_utf8Payload()
    {
        let original = Data("secret-payload".utf8)
        XCTAssertEqual(original.uuBase64UrlEncode().uuBase64UrlDecode(), original)
    }
}
