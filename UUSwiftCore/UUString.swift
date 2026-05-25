//
//  UUString.swift
//  Useful Utilities - Extensions for String
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

import Foundation
import UniformTypeIdentifiers

public extension String
{
    // Access a sub string based on integer start index and integer length.
    //
    // If the end index is out of bounds, will return as many characters as
    // available up to the end of the string.
    //
    // Out of bounds indices are clamped to fit within range of the string.
    //
    func uuSubString(_ from: Int, _ length: Int) -> String
    {
        var adjustedFrom = from
        if (adjustedFrom < 0)
        {
            adjustedFrom = 0
        }
        
        var adjustedLength = length
        if (adjustedLength > self.count)
        {
            adjustedLength = self.count
        }
        
        let start = self.index(self.startIndex, offsetBy: adjustedFrom, limitedBy: self.endIndex)
        var end = self.index(self.startIndex, offsetBy: (adjustedFrom + adjustedLength), limitedBy: self.endIndex)
        if (end == nil)
        {
            end = self.endIndex
        }
        
        if (start != nil && end != nil)
        {
            return String.init(self[start! ..< end!])
        }
        
        return ""
    }
    
    // Returns the first N characters of the string
    func uuFirstNChars(_ count: Int) -> String
    {
        return uuSubString(0, count)
    }
    
    // Returns the last N characters of the string
    func uuLastNChars(_ count: Int) -> String
    {
        return uuSubString(self.count - count, count)
    }
    
    private static let kUrlEncodingChars = "!*'();:@&=+$,/?%#[] "
    private static let kUrlEncodingCharSet = CharacterSet.init(charactersIn: kUrlEncodingChars).inverted
    
    // Percent encodes the following characters:
    //
    // !*'();:@&=+$,/?%#[]
    //
    func uuUrlEncoded() -> String
    {
        var encoded : String? = addingPercentEncoding(withAllowedCharacters: String.kUrlEncodingCharSet)
        if (encoded == nil)
        {
            encoded = self
        }
        
        return encoded!
    }
    
    // Trim whitespace from beginning and end of string
    func uuTrimWhitespace() -> String
    {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Returns a copy with the first character uppercased.
    ///
    /// An empty string returns an empty string. Used by ``uuSnakeToCamelCase()`` and ``uuSnakeToPascalCase()``.
    func uuFirstCapital() -> String
    {
        guard !isEmpty else { return "" }
        return prefix(1).uppercased() + dropFirst()
    }

    /// Converts a snake_case string to camelCase.
    ///
    /// The receiver is lowercased, split on underscores. The first segment is passed through ``uuFirstCapital()``
    /// then lowercased entirely so the result starts with a lowercase letter. Each later segment uses
    /// ``uuFirstCapital()`` when its length is greater than one; a single-character segment stays lowercase
    /// (so `a_b_c` becomes `abc`, while `user_name` becomes `userName`).
    ///
    /// - Returns: The camelCase string.
    func uuSnakeToCamelCase() -> String
    {
        let parts = lowercased().split(separator: "_", omittingEmptySubsequences: false)
        var result = ""
        for (index, sub) in parts.enumerated()
        {
            let s = String(sub)
            if index == 0
            {
                result += s.uuFirstCapital().lowercased()
            }
            else if s.count == 1
            {
                result += s
            }
            else
            {
                result += s.uuFirstCapital()
            }
        }
        return result
    }

    /// Converts a snake_case string to PascalCase.
    ///
    /// The receiver is lowercased, split on underscores, and each segment is capitalized with ``uuFirstCapital()``
    /// and concatenated (for example `user_name` becomes `UserName`).
    ///
    /// - Returns: The PascalCase string.
    func uuSnakeToPascalCase() -> String
    {
        let parts = lowercased().split(separator: "_", omittingEmptySubsequences: false)
        return parts.map { String($0).uuFirstCapital() }.joined()
    }

    // Parses this string as a decimal number
    func uuAsDecimalNumber() -> NSNumber?
    {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.number(from: self)
    }
    
    func uuToJsonObject(_ encoding : String.Encoding = .utf8) -> Any?
    {
        let encodedData = data(using: encoding)
        if (encodedData != nil)
        {
            return encodedData!.uuToJson()
        }
        else
        {
            return nil
        }
    }
    
    func uuToHexData() -> Data?
    {
        let length:Int = self.count
        
        // Must greater than zero and be divisible by two
        if (length <= 0 || (length % 2) != 0)
        {
            return nil
        }
        
        var data = Data()
        
        for i in stride(from: 0, to: length, by: 2)
        {
            let sc:Scanner = Scanner(string: self.uuSubString(i, 2)) //Substring was deprecated, so using uu
            
            var hex:UInt64 = 0
            if (sc.scanHexInt64(&hex))
            {
                var tmp:UInt8 = UInt8(hex)
                data.append(&tmp, count: MemoryLayout<UInt8>.size) //sizeof deprecated
            }
            else
            {
                return nil
            }
        }
        
        return data
    }
    
    func uuBase64UrlDecode() -> Data?
    {
        // Base64 URL mode swaps '-' with '+' and '_' with '/'
        var tmp = self
        tmp = tmp.replacingOccurrences(of: "-", with: "+")
        tmp = tmp.replacingOccurrences(of: "_", with: "/")
        
        let currentLength = tmp.lengthOfBytes(using: .utf8)
        let multipleOfFourLength = 4 * Int(ceil(Double(currentLength) / 4.0))
        
        // Base64 also requires padding to a multiple of four
        tmp = tmp.padding(toLength: multipleOfFourLength, withPad: "=", startingAt: 0)
        
        return Data(base64Encoded: tmp, options: .ignoreUnknownCharacters)
    }
    
    func uuIsValidEmail() -> Bool
    {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format:"SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
    
    // Converts a string assumed to be snake_case into camelCase
    func uuToCamelCase() -> String
    {
        let parts = split(separator: "_")
        var capitalizedParts = parts.map({ $0.capitalized })
        
        if (capitalizedParts.count > 0)
        {
            capitalizedParts[0] = capitalizedParts[0].lowercased()
        }
        
        return capitalizedParts.joined()
    }
    
    // Converts a string assumed to be camelCase into snake_case
    func uuToSnakeCase() -> String
    {
        var working = ""
        
        for c in self
        {
            if (c.isUppercase)
            {
                working.append("_")
            }
            
            working.append(c)
        }
        
        return working.lowercased()
    }
}

extension Int
{
    func uuLastDigit() -> Int
    {
        return Int("\(self)".uuLastNChars(1)) ?? 0
    }
}

// MARK: Number suffix extensions
public extension String
{
    private static let kUUDayOfMonthSuffixFirst = "st"
    private static let kUUDayOfMonthSuffixSecond = "nd"
    private static let kUUDayOfMonthSuffixThird = "rd"
    private static let kUUDayOfMonthSuffixNth = "th"
    
    private static let kUUDayOfMonthSuffixFirstKey  = "UUDayOfMonthSuffixFirstKey"
    private static let kUUDayOfMonthSuffixSecondKey = "UUDayOfMonthSuffixSecondKey"
    private static let kUUDayOfMonthSuffixThirdKey  = "UUDayOfMonthSuffixThirdKey"
    private static let kUUDayOfMonthSuffixNthKey    = "UUDayOfMonthSuffixNthKey"

    static func uuNumberSuffix(_ number: Int) -> String
    {
        switch (number.uuLastDigit())
        {
            case 1:
                return Bundle.main.localizedString(forKey: kUUDayOfMonthSuffixFirstKey, value: kUUDayOfMonthSuffixFirst, table: nil)
                
            case 2:
                return Bundle.main.localizedString(forKey: kUUDayOfMonthSuffixSecondKey, value: kUUDayOfMonthSuffixSecond, table: nil)
                
            case 3:
                return Bundle.main.localizedString(forKey: kUUDayOfMonthSuffixThirdKey, value: kUUDayOfMonthSuffixThird, table: nil)
            
            default:
                return Bundle.main.localizedString(forKey: kUUDayOfMonthSuffixNthKey, value: kUUDayOfMonthSuffixNth, table: nil)
        }
    }
}

// MARK: Filename/url string helpers
public extension String
{
    func uuRemoveQueryString() -> String
    {
        if let url = URL(string: self),
           let scheme = url.scheme,
           let host = url.host,
           !scheme.isEmpty,
           !host.isEmpty,
           !url.path.isEmpty
        {
            let result = "\(scheme)://\(host)\(url.path)"
            if (!result.isEmpty)
            {
               return result
            }
        }
                   
        return self
    }
    
    func uuGetFileName() -> String
    {
        let tmp = uuRemoveQueryString()
        let nsString = tmp as NSString
        let ext = nsString.lastPathComponent
        return ext
    }
    
    func uuGetFileExtension() -> String
    {
        let tmp = uuRemoveQueryString()
        let nsString = tmp as NSString
        let ext = nsString.pathExtension
        return ext
    }
    
    func uuGetMimeType() -> String?
    {
        let ext = uuGetFileExtension()
        if let type = UTType(filenameExtension: ext)
        {
            return type.preferredMIMEType
        }
        return nil
    }
}

public extension FixedWidthInteger
{
    /// Returns an N‑character string of `0`/`1` bits (two’s‑compliment),
    /// where N == Self.bitWidth (e.g. 8 for UInt8, 32 for Int32, etc.)
    func uuToBinaryString() -> String
    {
        var result = ""
        result.reserveCapacity(Self.bitWidth)
        for bit in (0..<Self.bitWidth).reversed()
        {
            let mask = Self(1) << bit
            result.append((self & mask) != 0 ? "1" : "0")
        }
        
        return result
    }
}
