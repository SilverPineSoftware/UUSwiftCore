//
//  UUBase64.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/26/26.
//  Copyright © 2026 Silver Pine Software, LLC. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//
//  Base64URL encoding and decoding.
//
//  - Alphabet: RFC 4648 §5 (URL- and filename-safe Base64; `-` and `_` replace `+` and `/`).
//  - Padding: RFC 7515 §2 (trailing `=` omitted on encode; restored on decode).
//
//  Used by JWT/JWS/JWE compact serialization (RFC 7515 / RFC 7516), PKCE code challenges
//  (RFC 7636), and other JOSE/OAuth profiles that require URL-safe, unpadded binary text.
//

import Foundation

// MARK: - Data

public extension Data
{
    /// Encodes bytes as an unpadded Base64URL string.
    ///
    /// Applies the URL-safe alphabet from RFC 4648 §5 (`-` and `_` instead of `+` and `/`)
    /// and omits all trailing `=` padding per RFC 7515 §2. An empty input produces an empty string.
    func uuBase64UrlEncode() -> String
    {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - String

public extension String
{
    /// Decodes a Base64URL string to bytes.
    ///
    /// Accepts the URL-safe alphabet from RFC 4648 §5 (`-`/`_`). Omitted `=` padding is restored
    /// before decoding, as required for JWS/JWE segments in RFC 7515 §2. Padded input is also
    /// accepted.
    ///
    /// Returns `nil` when the string cannot be decoded as Base64URL. Non-alphabet characters are
    /// ignored (see ``Data/Base64DecodingOptions/ignoreUnknownCharacters``), matching JWT segment
    /// parsing in ``UUJsonWebToken``.
    func uuBase64UrlDecode() -> Data?
    {
        var tmp = replacingOccurrences(of: "-", with: "+")
        tmp = tmp.replacingOccurrences(of: "_", with: "/")

        let currentLength = tmp.lengthOfBytes(using: .utf8)
        let multipleOfFourLength = 4 * Int(ceil(Double(currentLength) / 4.0))
        tmp = tmp.padding(toLength: multipleOfFourLength, withPad: "=", startingAt: 0)

        return Data(base64Encoded: tmp, options: .ignoreUnknownCharacters)
    }
}
