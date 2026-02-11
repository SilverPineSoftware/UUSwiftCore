//
//  UUCompression.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 2/10/26.
//

import Foundation
import Compression
#if canImport(zlib)
import zlib
#endif

fileprivate let LOG_TAG: String = "UUCompression"

// MARK: - ZIP constants (local file header)

private let zipLocalFileHeaderSignature: UInt32 = 0x04034b50
private let zipDataDescriptorSignature: UInt32 = 0x08074b50
private let zipCompressionStored: UInt16 = 0
private let zipCompressionDeflate: UInt16 = 8
/// General purpose bit 3: sizes are in a data descriptor after the compressed data (used by macOS Finder, etc.)
private let zipFlagDataDescriptor: UInt16 = 8

// Zlib header for raw deflate (zip uses deflate without zlib wrapper; Apple's API expects zlib)
private let zlibHeader: [UInt8] = [0x78, 0x9C]

// Central directory (APPNOTE 4.3.16, 4.3.12)
private let zipEOCDSignature: UInt32 = 0x06054b50
private let zipCentralFileHeaderSignature: UInt32 = 0x02014b50

// MARK: - Central directory (parsed from end of ZIP per APPNOTE)

public struct UUZipCentralDirectory
{
    let entryCount: Int
    let centralDirectoryOffset: Int
    let centralDirectorySize: Int
    let commentLength: Int
    let comment: Data?
    let entries: [UUZipCentralDirectoryEntry]
}

public struct UUZipCentralDirectoryEntry
{
    let fileName: String
    let compressionMethod: UInt16
    let compressedSize: Int
    let uncompressedSize: Int
    let localHeaderOffset: Int
    let crc32: UInt32
    let generalPurposeBitFlag: UInt16
}

// MARK: - Data extension

public extension Data
{
    /// Unzips the contents of this data (ZIP format) into the given destination directory.
    /// Uses the central directory to locate each entry, then reads local file headers and payloads.
    /// Skips directory entries and only extracts files. Paths are validated to prevent Zip Slip.
    func uuUnzip(destinationFolder: URL)
    {
        do
        {
            guard let centralDir = uuParseCentralDirectory() else
            {
                UULog.error(tag: LOG_TAG, message: "uuUnzip: no central directory; extraction requires a valid ZIP with central directory")
                return
            }
            
            let destDir = destinationFolder.standardizedFileURL.resolvingSymlinksInPath()
            let count = self.count

            for entry in centralDir.entries
            {
                if entry.fileName.hasSuffix("/") { continue }

                let resolvedPath = destDir.resolvingSymlinksInPath().appendingPathComponent(entry.fileName).standardizedFileURL.resolvingSymlinksInPath()
                let destDirPath = destDir.path
                let resolvedPathStr = resolvedPath.path
                let destPrefix = destDirPath.hasSuffix("/") ? destDirPath : destDirPath + "/"
                if resolvedPathStr != destDirPath && !resolvedPathStr.hasPrefix(destPrefix)
                {
                    UULog.error(tag: LOG_TAG, message: "Potential Zip Slip attempt: \(entry.fileName)")
                    continue
                }

                let localHeaderOffset = entry.localHeaderOffset
                guard localHeaderOffset + 30 <= count else { continue }
                let sig = uuUInt32(at: localHeaderOffset) ?? 0
                guard sig == zipLocalFileHeaderSignature else { continue }

                let fileNameLength = Int(uuUInt16(at: localHeaderOffset + 26) ?? 0)
                let extraFieldLength = Int(uuUInt16(at: localHeaderOffset + 28) ?? 0)
                let headerEnd = localHeaderOffset + 30 + fileNameLength + extraFieldLength

                let compressedSize = entry.compressedSize
                let uncompressedSize = entry.uncompressedSize
                guard headerEnd + compressedSize <= count else { continue }

                let parentDir = resolvedPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

                let compressedPayload = subdata(in: headerEnd..<(headerEnd + compressedSize))
                let outData: Data
                switch entry.compressionMethod
                {
                case zipCompressionStored:
                    outData = compressedPayload
                case zipCompressionDeflate:
                    guard let decompressed = Self.uuDecompressDeflate(compressedPayload, uncompressedSize: uncompressedSize) else
                    {
                        UULog.error(tag: LOG_TAG, message: "Failed to decompress entry: \(entry.fileName)")
                        continue
                    }
                    outData = decompressed
                default:
                    UULog.error(tag: LOG_TAG, message: "Unsupported compression method \(entry.compressionMethod) for entry: \(entry.fileName)")
                    continue
                }

                let computedCrc = Self.uuCrc32(outData)
                if computedCrc != entry.crc32
                {
                    UULog.error(tag: LOG_TAG, message: "CRC-32 mismatch for entry '\(entry.fileName)': expected \(entry.crc32), got \(computedCrc); skipping write")
                    continue
                }

                try outData.write(to: resolvedPath)
            }
        }
        catch
        {
            UULog.error(tag: LOG_TAG, message: "uuUnzip failed: \(String(describing: error))")
        }
    }

    /// Parses the ZIP central directory from the end of the byte array (per APPNOTE: EOCD at end, then central directory).
    /// Returns nil if the data does not contain a valid End of central directory record or central directory.
    func uuParseCentralDirectory() -> UUZipCentralDirectory?
    {
        let count = self.count
        guard count >= 22 else { return nil }
        let eocdOffset = indexOfEOCD(limit: count)
        guard let eocd = eocdOffset else { return nil }
        let totalEntries = Int(uuUInt16(at: eocd + 10) ?? 0)
        let centralDirSize = Int(uuUInt32(at: eocd + 12) ?? 0)
        let centralDirOffset = Int(uuUInt32(at: eocd + 16) ?? 0)
        let commentLength = Int(uuUInt16(at: eocd + 20) ?? 0)
        guard eocd + 22 + commentLength <= count,
              centralDirOffset >= 0,
              centralDirOffset + centralDirSize <= count
        else { return nil }
        let comment: Data? = commentLength > 0 ? subdata(in: (eocd + 22)..<(eocd + 22 + commentLength)) : nil
        var entries: [UUZipCentralDirectoryEntry] = []
        var pos = centralDirOffset
        for _ in 0..<totalEntries
        {
            guard pos + 46 <= count else { break }
            let sig = uuUInt32(at: pos) ?? 0
            guard sig == zipCentralFileHeaderSignature else { break }
            let compressionMethod = uuUInt16(at: pos + 10) ?? 0
            let crc32 = uuUInt32(at: pos + 16) ?? 0
            let compressedSize = Int(uuUInt32(at: pos + 20) ?? 0)
            let uncompressedSize = Int(uuUInt32(at: pos + 24) ?? 0)
            let fileNameLength = Int(uuUInt16(at: pos + 28) ?? 0)
            let extraFieldLength = Int(uuUInt16(at: pos + 30) ?? 0)
            let fileCommentLength = Int(uuUInt16(at: pos + 32) ?? 0)
            let localHeaderOffset = Int(uuUInt32(at: pos + 42) ?? 0)
            let generalPurposeBitFlag = uuUInt16(at: pos + 8) ?? 0
            let nameStart = pos + 46
            guard nameStart + fileNameLength + extraFieldLength + fileCommentLength <= count, fileNameLength > 0 else { break }
            let nameData = subdata(in: nameStart..<(nameStart + fileNameLength))
            let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""
            entries.append(UUZipCentralDirectoryEntry(
                fileName: fileName,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset,
                crc32: crc32,
                generalPurposeBitFlag: generalPurposeBitFlag
            ))
            pos = nameStart + fileNameLength + extraFieldLength + fileCommentLength
        }
        guard entries.count == totalEntries else { return nil }
        return UUZipCentralDirectory(
            entryCount: totalEntries,
            centralDirectoryOffset: centralDirOffset,
            centralDirectorySize: centralDirSize,
            commentLength: commentLength,
            comment: comment,
            entries: entries
        )
    }

    /// Scans backwards from the end for the End of central directory signature (0x06054b50).
    private func indexOfEOCD(limit: Int) -> Int?
    {
        let minEOCDSize = 22
        var i = limit - minEOCDSize
        while i >= 0
        {
            if (uuUInt32(at: i) ?? 0) == zipEOCDSignature
            {
                let commentLen = Int(uuUInt16(at: i + 20) ?? 0)
                if i + 22 + commentLen == limit { return i }
            }
            i -= 1
        }
        return nil
    }

    /// Decompresses raw deflate data (as used in ZIP) by wrapping with zlib header and Adler-32 placeholder and using Compression framework.
    /// If the data already starts with a zlib header (0x78), it is used as-is. Otherwise we prepend header and append 4-byte Adler-32 placeholder.
    /// If the first attempt fails (e.g. wrong size from a false-positive data descriptor), retries with a larger buffer.
    static func uuDecompressDeflate(_ deflateData: Data, uncompressedSize: Int) -> Data?
    {
        let zlibData: Data
        if deflateData.count >= 2, deflateData[0] == 0x78
        {
            zlibData = deflateData
        }
        else
        {
            var built = Data(zlibHeader)
            built.append(deflateData)
            built.append(contentsOf: [0x00 as UInt8, 0x00, 0x00, 0x00])
            zlibData = built
        }

        let maxFallback = 32 * 1024 * 1024
        let fallbackCapacity = Swift.min(Swift.max(uncompressedSize * 4, 256 * 1024), maxFallback)
        let capacities = [uncompressedSize, fallbackCapacity].filter { $0 > 0 }
        for destCapacity in capacities
        {
            let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
            defer { destBuffer.deallocate() }

            let decodedCount = zlibData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
                guard let srcBase = srcPtr.baseAddress else { return 0 }
                return compression_decode_buffer(
                    destBuffer,
                    destCapacity,
                    srcBase.bindMemory(to: UInt8.self, capacity: zlibData.count),
                    zlibData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            if decodedCount > 0
            {
                return Data(bytes: destBuffer, count: decodedCount)
            }
        }

        if let streamed = uuDecompressDeflateStreaming(zlibData) { return streamed }
#if canImport(zlib)
        return uuDecompressDeflateRawZlib(deflateData)
#else
        return nil
#endif
    }

    /// Fallback for raw deflate (ZIP-style) using zlib's inflate with -MAX_WBITS.
#if canImport(zlib)
    private static func uuDecompressDeflateRawZlib(_ deflateData: Data) -> Data?
    {
        guard !deflateData.isEmpty else { return nil }
        var stream = z_stream()
        defer { inflateEnd(&stream) }

        let result = deflateData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return nil }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcBase)
            stream.avail_in = uInt(deflateData.count)

            if inflateInit2_(&stream, -Int32(MAX_WBITS), ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) != Z_OK
            {
                return nil
            }

            let chunkSize = 65_536
            let dstBuffer = UnsafeMutablePointer<Bytef>.allocate(capacity: chunkSize)
            defer { dstBuffer.deallocate() }
            var out = Data()
            out.reserveCapacity(deflateData.count * 2)

            repeat
            {
                stream.next_out = dstBuffer
                stream.avail_out = uInt(chunkSize)
                let status = inflate(&stream, Z_NO_FLUSH)
                if status != Z_OK && status != Z_STREAM_END { return nil }
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 { out.append(dstBuffer, count: produced) }
                if status == Z_STREAM_END { break }
            }
            while stream.avail_out == 0

            return out
        }
        return result
    }
#endif

    /// Fallback for large or problematic zlib streams using the streaming API.
    private static func uuDecompressDeflateStreaming(_ zlibData: Data) -> Data?
    {
        let dstSize = 65_536
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstSize)
        defer { dstBuffer.deallocate() }

        var stream = compression_stream(
            dst_ptr: dstBuffer,
            dst_size: dstSize,
            src_ptr: dstBuffer,
            src_size: 0,
            state: nil
        )
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else
        {
            return nil
        }
        defer { compression_stream_destroy(&stream) }

        var result = Data()
        result.reserveCapacity(zlibData.count * 2)

        let success = zlibData.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Bool in
            guard let srcBase = srcPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            stream.src_ptr = srcBase
            stream.src_size = zlibData.count

            while true
            {
                stream.dst_ptr = dstBuffer
                stream.dst_size = dstSize
                let flags: Int32 = stream.src_size == 0 ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let status = compression_stream_process(&stream, flags)

                if status == COMPRESSION_STATUS_ERROR { return false }
                let produced = dstSize - stream.dst_size
                if produced > 0 { result.append(dstBuffer, count: produced) }
                if status == COMPRESSION_STATUS_END { return true }
            }
        }
        return success ? result : nil
    }

    /// CRC-32 (ZIP standard polynomial, same as ISO 3309). Used to validate decompressed entry data.
    private static func uuCrc32(_ data: Data) -> UInt32
    {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data
        {
            crc = (crc >> 8) ^ zipCrc32Table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private let zipCrc32Table: [UInt32] = (0..<256).map { i in
    var c = UInt32(i)
    for _ in 0..<8
    {
        c = (c & 1) == 1 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
    }
    return c
}
