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

// MARK: - Data extension

public extension Data
{
    /// Unzips the contents of this data (ZIP format) into the given destination directory.
    /// Skips directory entries and only extracts files. Paths are validated to prevent Zip Slip.
    /// Intended for ZIP data received from a web service or other in-memory source.
    ///
    /// - Parameter destinationFolder: File URL for the destination directory (must be a directory).
    func uuUnzip(destinationFolder: URL)
    {
        do
        {
            let destDir = destinationFolder.standardizedFileURL.resolvingSymlinksInPath()
            var offset = 0
            let count = self.count

            while offset + 30 <= count
            {
                let sig = uuUInt32(at: offset) ?? 0
                if sig != zipLocalFileHeaderSignature
                {
                    offset += 1
                    continue
                }

                let flags = uuUInt16(at: offset + 6) ?? 0
                let compressionMethod = uuUInt16(at: offset + 8) ?? 0
                var compressedSize = Int(uuUInt32(at: offset + 18) ?? 0)
                var uncompressedSize = Int(uuUInt32(at: offset + 22) ?? 0)
                let fileNameLength = Int(uuUInt16(at: offset + 26) ?? 0)
                let extraFieldLength = Int(uuUInt16(at: offset + 28) ?? 0)

                let headerEnd = offset + 30 + fileNameLength + extraFieldLength
                let usesDataDescriptor = (flags & zipFlagDataDescriptor) != 0

                var payloadEnd: Int
                if usesDataDescriptor
                {
                    // Sizes in header are 0; find data descriptor (signature 0x08074b50) after the compressed data.
                    // Validate candidates: compressed size in the descriptor must equal (descriptorOffset - headerEnd),
                    // otherwise we may have hit 0x08074b50 inside the compressed stream (false positive).
                    guard let descriptorOffset = indexOfValidDataDescriptor(headerEnd: headerEnd, limit: count) else
                    {
                        break
                    }
                    compressedSize = Int(uuUInt32(at: descriptorOffset + 8) ?? 0)
                    uncompressedSize = Int(uuUInt32(at: descriptorOffset + 12) ?? 0)
                    payloadEnd = descriptorOffset
                }
                else
                {
                    guard headerEnd + compressedSize <= count else { break }
                    payloadEnd = headerEnd + compressedSize
                }

                guard fileNameLength > 0, headerEnd <= payloadEnd else { break }

                let nameData = subdata(in: (offset + 30)..<(offset + 30 + fileNameLength))
                guard let entryName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) else
                {
                    offset = usesDataDescriptor ? (payloadEnd + 16) : payloadEnd
                    continue
                }

                // Skip directory entries (name ends with /)
                if entryName.hasSuffix("/")
                {
                    offset = usesDataDescriptor ? (payloadEnd + 16) : payloadEnd
                    continue
                }

                // Normalize paths to prevent Zip Slip
                let resolvedPath = destDir.resolvingSymlinksInPath().appendingPathComponent(entryName).standardizedFileURL.resolvingSymlinksInPath()
                let destDirPath = destDir.path
                let resolvedPathStr = resolvedPath.path
                let destPrefix = destDirPath.hasSuffix("/") ? destDirPath : destDirPath + "/"
                if resolvedPathStr != destDirPath && !resolvedPathStr.hasPrefix(destPrefix)
                {
                    UULog.error(tag: LOG_TAG, message: "Potential Zip Slip attempt: \(entryName)")
                    offset = usesDataDescriptor ? (payloadEnd + 16) : payloadEnd
                    continue
                }

                // Create parent directories
                let parentDir = resolvedPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

                let compressedPayload = subdata(in: headerEnd..<payloadEnd)
                let outData: Data
                if compressionMethod == zipCompressionStored
                {
                    outData = compressedPayload
                }
                else if compressionMethod == zipCompressionDeflate
                {
                    guard let decompressed = Self.uuDecompressDeflate(compressedPayload, uncompressedSize: uncompressedSize) else
                    {
                        UULog.error(tag: LOG_TAG, message: "Failed to decompress entry: \(entryName)")
                        offset = usesDataDescriptor ? (payloadEnd + 16) : payloadEnd
                        continue
                    }
                    outData = decompressed
                }
                else
                {
                    UULog.error(tag: LOG_TAG, message: "Unsupported compression method \(compressionMethod) for entry: \(entryName)")
                    offset = usesDataDescriptor ? (payloadEnd + 16) : payloadEnd
                    continue
                }

                try outData.write(to: resolvedPath)
                offset = usesDataDescriptor ? (payloadEnd + 16) : payloadEnd
            }
        }
        catch
        {
            UULog.error(tag: LOG_TAG, message: "uuUnzip failed: \(String(describing: error))")
        }
    }

    /// Searches for a valid ZIP data descriptor: signature 0x08074b50 with compressed size matching payload length.
    /// This avoids false positives when 0x08074b50 appears inside a large deflate payload.
    private func indexOfValidDataDescriptor(headerEnd: Int, limit: Int) -> Int?
    {
        var i = headerEnd
        while i + 16 <= limit
        {
            if (uuUInt32(at: i) ?? 0) != zipDataDescriptorSignature
            {
                i += 1
                continue
            }
            let descriptorCompressedSize = Int(uuUInt32(at: i + 8) ?? 0)
            let payloadLength = i - headerEnd
            if descriptorCompressedSize == payloadLength
            {
                return i
            }
            i += 1
        }
        return nil
    }

    /// Decompresses raw deflate data (as used in ZIP) by wrapping with zlib header and using Compression framework.
    private static func uuDecompressDeflate(_ deflateData: Data, uncompressedSize: Int) -> Data?
    {
        var zlibData = Data(zlibHeader)
        zlibData.append(deflateData)

        let destCapacity = uncompressedSize
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
        guard decodedCount > 0 else { return nil }
        return Data(bytes: destBuffer, count: decodedCount)
    }
}
