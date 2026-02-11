//
//  UUCompression.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 2/10/26.
//

import Foundation
import Compression

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

    /// Decompresses raw deflate data (as used in ZIP) by wrapping with zlib header and using Compression framework.
    /// If the first attempt fails (e.g. wrong size from a false-positive data descriptor), retries with a larger buffer.
    private static func uuDecompressDeflate(_ deflateData: Data, uncompressedSize: Int) -> Data?
    {
        var zlibData = Data(zlibHeader)
        zlibData.append(deflateData)

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
        return nil
    }
}
