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
/// General purpose bit 0: file is encrypted (APPNOTE 4.4.4).
private let zipFlagEncrypted: UInt16 = 1
/// General purpose bit 3: sizes are in a data descriptor after the compressed data (used by macOS Finder, etc.)
private let zipFlagDataDescriptor: UInt16 = 8

// Zlib header for raw deflate (zip uses deflate without zlib wrapper; Apple's API expects zlib)
private let zlibHeader: [UInt8] = [0x78, 0x9C]

// Central directory (APPNOTE 4.3.16, 4.3.12)
private let zipEOCDSignature: UInt32 = 0x06054b50
private let zipCentralFileHeaderSignature: UInt32 = 0x02014b50

// MARK: - Little-endian reads (ZIP spec: all multi-byte values are little-endian)

private extension Data
{
    func zipUInt16(at index: Int) -> UInt16?
    {
        guard index + 2 <= count, let b0 = uuUInt8(at: index), let b1 = uuUInt8(at: index + 1) else { return nil }
        return UInt16(b0) | (UInt16(b1) << 8)
    }

    func zipUInt32(at index: Int) -> UInt32?
    {
        guard index + 4 <= count else { return nil }
        let b0 = UInt32(uuUInt8(at: index) ?? 0), b1 = UInt32(uuUInt8(at: index + 1) ?? 0),
            b2 = UInt32(uuUInt8(at: index + 2) ?? 0), b3 = UInt32(uuUInt8(at: index + 3) ?? 0)
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    func zipUInt64(at index: Int) -> UInt64?
    {
        guard index + 8 <= count else { return nil }
        let lo = zipUInt32(at: index) ?? 0, hi = zipUInt32(at: index + 4) ?? 0
        return UInt64(lo) | (UInt64(hi) << 32)
    }

    /// Reads Zip64 extended info from the local file header extra field (block ID 0x0001).
    /// Returns (compressedSize?, uncompressedSize?) for values present in the block; caller overrides only the ones they need (when local header had 0xFFFFFFFF).
    func readLocalZip64Sizes(at localHeaderOffset: Int, fileNameLength: Int, extraFieldLength: Int, localCompressed32: UInt32, localUncompressed32: UInt32) -> (compressed: Int?, uncompressed: Int?)?
    {
        guard localCompressed32 == 0xFFFFFFFF || localUncompressed32 == 0xFFFFFFFF,
              extraFieldLength >= 4 else { return nil }
        let extraStart = localHeaderOffset + 30 + fileNameLength
        guard extraStart + extraFieldLength <= count else { return nil }
        var extraOffset = 0
        while extraOffset + 4 <= extraFieldLength
        {
            let id = zipUInt16(at: extraStart + extraOffset) ?? 0
            let blockSize = Int(zipUInt16(at: extraStart + extraOffset + 2) ?? 0)
            extraOffset += 4
            guard extraOffset + blockSize <= extraFieldLength else { break }
            if id != 0x0001 { extraOffset += blockSize; continue }
            let blockStart = extraStart + extraOffset
            var zip64Off = 0
            var uncompressed: Int? = nil
            var compressed: Int? = nil
            if localUncompressed32 == 0xFFFFFFFF, zip64Off + 8 <= blockSize
            {
                uncompressed = Int(truncatingIfNeeded: zipUInt64(at: blockStart + zip64Off) ?? 0)
                zip64Off += 8
            }
            if localCompressed32 == 0xFFFFFFFF, zip64Off + 8 <= blockSize
            {
                compressed = Int(truncatingIfNeeded: zipUInt64(at: blockStart + zip64Off) ?? 0)
                zip64Off += 8
            }
            if compressed != nil || uncompressed != nil { return (compressed, uncompressed) }
            break
        }
        return nil
    }
}

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
    /// When `verifyCRC` is true (default), entries whose decompressed data does not match the stored CRC-32 are skipped and not written.
    func uuUnzip(destinationFolder: URL, verifyCRC: Bool = true)
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
                if (entry.generalPurposeBitFlag & zipFlagEncrypted) != 0
                {
                    UULog.error(tag: LOG_TAG, message: "Skipping encrypted entry (not supported): \(entry.fileName)")
                    continue
                }

                let pathInZip = entry.fileName.replacingOccurrences(of: "\\", with: "/")
                let resolvedPath = destDir.resolvingSymlinksInPath().appendingPathComponent(pathInZip).standardizedFileURL.resolvingSymlinksInPath()
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
                let sig = zipUInt32(at: localHeaderOffset) ?? 0
                guard sig == zipLocalFileHeaderSignature else { continue }

                let fileNameLength = Int(zipUInt16(at: localHeaderOffset + 26) ?? 0)
                let extraFieldLength = Int(zipUInt16(at: localHeaderOffset + 28) ?? 0)
                let headerEnd = localHeaderOffset + 30 + fileNameLength + extraFieldLength

                var compressedSize = entry.compressedSize
                var uncompressedSize = entry.uncompressedSize
                let localCompressed32 = zipUInt32(at: localHeaderOffset + 18) ?? 0
                let localUncompressed32 = zipUInt32(at: localHeaderOffset + 22) ?? 0
                if localCompressed32 == 0xFFFFFFFF || localUncompressed32 == 0xFFFFFFFF
                {
                    if let result = readLocalZip64Sizes(at: localHeaderOffset, fileNameLength: fileNameLength, extraFieldLength: extraFieldLength, localCompressed32: localCompressed32, localUncompressed32: localUncompressed32)
                    {
                        if let cs = result.compressed { compressedSize = cs }
                        if let ucs = result.uncompressed { uncompressedSize = ucs }
                    }
                }
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

                if verifyCRC
                {
                    let computedCrc = Self.uuCrc32(outData)
                    if computedCrc != entry.crc32
                    {
                        UULog.error(tag: LOG_TAG, message: "CRC-32 mismatch for entry '\(entry.fileName)': expected \(entry.crc32), got \(computedCrc); skipping write")
                        continue
                    }
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
        let totalEntries = Int(zipUInt16(at: eocd + 10) ?? 0)
        let centralDirSize = Int(zipUInt32(at: eocd + 12) ?? 0)
        let centralDirOffset = Int(zipUInt32(at: eocd + 16) ?? 0)
        let commentLength = Int(zipUInt16(at: eocd + 20) ?? 0)
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
            let sig = zipUInt32(at: pos) ?? 0
            guard sig == zipCentralFileHeaderSignature else { break }
            let compressionMethod = zipUInt16(at: pos + 10) ?? 0
            let crc32 = zipUInt32(at: pos + 16) ?? 0
            var compressedSize = Int(zipUInt32(at: pos + 20) ?? 0)
            var uncompressedSize = Int(zipUInt32(at: pos + 24) ?? 0)
            let fileNameLength = Int(zipUInt16(at: pos + 28) ?? 0)
            let extraFieldLength = Int(zipUInt16(at: pos + 30) ?? 0)
            let fileCommentLength = Int(zipUInt16(at: pos + 32) ?? 0)
            var localHeaderOffset = Int(zipUInt32(at: pos + 42) ?? 0)
            let diskNumberStart = zipUInt16(at: pos + 34) ?? 0
            let generalPurposeBitFlag = zipUInt16(at: pos + 8) ?? 0
            let nameStart = pos + 46
            guard nameStart + fileNameLength + extraFieldLength + fileCommentLength <= count, fileNameLength > 0 else { break }

            let extraStart = nameStart + fileNameLength
            if extraFieldLength >= 4
            {
                var extraOffset = 0
                while extraOffset + 4 <= extraFieldLength
                {
                    let id = zipUInt16(at: extraStart + extraOffset) ?? 0
                    let blockSize = Int(zipUInt16(at: extraStart + extraOffset + 2) ?? 0)
                    extraOffset += 4
                    guard extraOffset + blockSize <= extraFieldLength else { break }
                    if id == 0x0001, blockSize >= 8
                    {
                        var zip64Offset = 0
                        if UInt32(truncatingIfNeeded: uncompressedSize) == 0xFFFFFFFF
                        {
                            if zip64Offset + 8 <= blockSize
                            {
                                uncompressedSize = Int(truncatingIfNeeded: zipUInt64(at: extraStart + extraOffset + zip64Offset) ?? 0)
                                zip64Offset += 8
                            }
                        }
                        if UInt32(truncatingIfNeeded: compressedSize) == 0xFFFFFFFF
                        {
                            if zip64Offset + 8 <= blockSize
                            {
                                compressedSize = Int(truncatingIfNeeded: zipUInt64(at: extraStart + extraOffset + zip64Offset) ?? 0)
                                zip64Offset += 8
                            }
                        }
                        if UInt32(truncatingIfNeeded: localHeaderOffset) == 0xFFFFFFFF
                        {
                            if zip64Offset + 8 <= blockSize
                            {
                                localHeaderOffset = Int(truncatingIfNeeded: zipUInt64(at: extraStart + extraOffset + zip64Offset) ?? 0)
                                zip64Offset += 8
                            }
                        }
                        if diskNumberStart == 0xFFFF, zip64Offset + 4 <= blockSize
                        {
                            zip64Offset += 4
                        }
                        break
                    }
                    extraOffset += blockSize
                }
            }

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
            if (zipUInt32(at: i) ?? 0) == zipEOCDSignature
            {
                let commentLen = Int(zipUInt16(at: i + 20) ?? 0)
                if i + 22 + commentLen == limit { return i }
            }
            i -= 1
        }
        return nil
    }

    /// Decompresses deflate data (ZIP uses raw deflate with no zlib wrapper).
    /// When data does not start with a zlib header (0x78), treats as raw deflate and uses zlib inflate with -MAX_WBITS when available for correct ZIP output.
    /// When data has a zlib header, uses Compression framework (buffer then streaming). Retries with larger buffer if needed.
    static func uuDecompressDeflate(_ deflateData: Data, uncompressedSize: Int) -> Data?
    {
#if canImport(zlib)
        if deflateData.count >= 2, deflateData[0] == 0x78
        {
            return uuDecompressDeflateZlibWrapped(deflateData, uncompressedSize: uncompressedSize)
        }
        if let raw = uuDecompressDeflateRawZlib(deflateData) { return raw }
        var wrapped = Data(zlibHeader)
        wrapped.append(deflateData)
        wrapped.append(contentsOf: [0x00 as UInt8, 0x00, 0x00, 0x00])
        return uuDecompressDeflateZlibWrapped(wrapped, uncompressedSize: uncompressedSize)
#else
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
        return uuDecompressDeflateZlibWrapped(zlibData, uncompressedSize: uncompressedSize)
#endif
    }

    private static func uuDecompressDeflateZlibWrapped(_ zlibData: Data, uncompressedSize: Int) -> Data?
    {
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
        return nil
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
