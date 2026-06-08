//
//  UUCompressionTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 2/10/26.
//

import XCTest
import Foundation
@testable import UUSwiftCore

final class UUCompressionTests: XCTestCase
{
    // MARK: - Invalid data (no valid zip)

    func test_unzipInvalidData()
    {
        let invalidData = UURandom.randomBytes(length: 1024)
        let outputFolder = makeOutputFolder()

        invalidData.uuUnzip(destinationFolder: outputFolder)

        printUnzippedFolderContents(outputFolder)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: outputFolder.path),
            "Output folder should not be created when unzipping invalid data"
        )
    }

    // MARK: - Valid zip (1, 2, 100 files)

    func test_unzip_1()
    {
        let zipData = makeZipData(fileCount: 1)
        let outputFolder = makeOutputFolder()

        zipData.uuUnzip(destinationFolder: outputFolder)

        printUnzippedFolderContents(outputFolder)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: outputFolder.path),
            "Output folder should exist after unzip"
        )
        assertExtractedFileCount(in: outputFolder, expected: 1)
    }

    func test_unzip_2()
    {
        let zipData = makeZipData(fileCount: 2)
        let outputFolder = makeOutputFolder()

        zipData.uuUnzip(destinationFolder: outputFolder)

        printUnzippedFolderContents(outputFolder)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: outputFolder.path),
            "Output folder should exist after unzip"
        )
        assertExtractedFileCount(in: outputFolder, expected: 2)
    }

    func test_unzip_100()
    {
        let zipData = makeZipData(fileCount: 100)
        let outputFolder = makeOutputFolder()

        zipData.uuUnzip(destinationFolder: outputFolder)

        printUnzippedFolderContents(outputFolder)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: outputFolder.path),
            "Output folder should exist after unzip"
        )
        assertExtractedFileCount(in: outputFolder, expected: 100)
    }

    // MARK: - Data descriptor (streaming) format

    func test_unzip_withDataDescriptorFormat()
    {
        let zipData = makeZipDataWithDataDescriptor(fileCount: 3)
        let outputFolder = makeOutputFolder()
        zipData.uuUnzip(destinationFolder: outputFolder)
        printUnzippedFolderContents(outputFolder)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: outputFolder.path),
            "Output folder should exist after unzip"
        )
        assertExtractedFileCount(in: outputFolder, expected: 3)
        assertExtractedFiles(named: ["stream_file_0.txt", "stream_file_1.txt", "stream_file_2.txt"], in: outputFolder)
    }

    // MARK: - Resource zip (firmware_decoded.zip)

    func test_unzipFile_fromWindows()
    {
        doUnzipFile("zip_data_windows")
    }
    
    func test_unzipFile_fromMac()
    {
        doUnzipFile("zip_data")
    }
    
    func test_unzipFile_fromCommandLineMac()
    {
        doUnzipFile("zip_cmd_line")
    }

    // MARK: - Central directory parsing

    func test_parseCentralDirectory_zip_cmd_line()
    {
        doParseCentralDirectory(named: "zip_cmd_line", expectedFileNames: ["file_a.txt", "file_b.txt", "file_c.txt"])
    }

    func test_parseCentralDirectory_zip_data_windows()
    {
        doParseCentralDirectory(named: "zip_data_windows", expectedFileNames: ["file_a.txt", "file_b.txt", "file_c.txt"])
    }

    func test_parseCentralDirectory_zip_data()
    {
        doParseCentralDirectory(named: "zip_data", expectedFileNames: ["file_a.txt", "file_b.txt", "file_c.txt"])
    }

    private func doParseCentralDirectory(named resourceName: String, expectedFileNames: [String])
    {
        guard let zipURL = Bundle.module.url(forResource: resourceName, withExtension: "zip") else
        {
            XCTFail("\(resourceName).zip not found in test bundle")
            return
        }
        let zipData: Data
        do
        {
            zipData = try Data(contentsOf: zipURL)
        }
        catch
        {
            XCTFail("Failed to load \(resourceName).zip: \(error)")
            return
        }
        guard let centralDir = zipData.uuParseCentralDirectory() else
        {
            XCTFail("uuParseCentralDirectory() returned nil for \(resourceName).zip")
            return
        }
        XCTAssertGreaterThanOrEqual(centralDir.entryCount, expectedFileNames.count, "Central directory should have at least \(expectedFileNames.count) entries")
        let names = Set(centralDir.entries.map { $0.fileName })
        for expected in expectedFileNames
        {
            XCTAssertTrue(names.contains(expected), "Expected entry '\(expected)' in central directory, got: \(names)")
        }
        XCTAssertGreaterThan(centralDir.centralDirectoryOffset, 0, "Central directory offset should be positive")
        XCTAssertGreaterThan(centralDir.centralDirectorySize, 0, "Central directory size should be positive")
        XCTAssertEqual(centralDir.entries.count, centralDir.entryCount, "Parsed entry count should match EOCD")
    }

    private func doUnzipFile(_ named: String)
    {
        guard let zipURL = Bundle.module.url(forResource: named, withExtension: "zip") else
        {
            XCTFail("\(named).zip not found in test bundle")
            return
        }
        let zipData: Data
        do
        {
            zipData = try Data(contentsOf: zipURL)
        }
        catch
        {
            XCTFail("Failed to load \(named).zip: \(error)")
            return
        }
        let outputFolder = makeOutputFolder()
        zipData.uuUnzip(destinationFolder: outputFolder)
        printUnzippedFolderContents(outputFolder)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: outputFolder.path),
            "Output folder should exist after unzip"
        )
        
        assertExtractedFiles(named: ["file_a.txt", "file_b.txt", "file_c.txt"], in: outputFolder)
    }

    private func assertExtractedFiles(named names: [String], in directory: URL)
    {
        for name in names
        {
            let fileURL = directory.appendingPathComponent(name)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: fileURL.path),
                "Expected file '\(name)' in extracted folder"
            )
        }
    }
    
    // MARK: - Helpers

    private func printUnzippedFolderContents(_ directory: URL)
    {
        guard FileManager.default.fileExists(atPath: directory.path) else
        {
            print("UUCompressionTests: No folder exists at: \(directory.path)")
            return
        }
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        while let url = enumerator.nextObject() as? URL
        {
            print("UUCompressionTests: \(url.path)")
        }
    }

    private func makeOutputFolder() -> URL
    {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("uu_compression_tests_\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: dir)
        return dir
    }

    private func assertExtractedFileCount(in directory: URL, expected: Int)
    {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else {
            XCTFail("Could not list contents of \(directory.path)")
            return
        }
        let files = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
        XCTAssertEqual(
            files.count,
            expected,
            "Expected \(expected) extracted files, got \(files.count)"
        )
    }

    /// Creates ZIP data in memory with a proper central directory and EOCD.
    /// Contains `fileCount` files: random_file_0.txt … random_file_N-1.txt,
    /// each with 1024 bytes of random hex string as UTF-8. Uses stored compression only.
    private func makeZipData(fileCount: Int) -> Data
    {
        let localFileHeaderSignature: UInt32 = 0x04034b50
        let centralFileHeaderSignature: UInt32 = 0x02014b50
        let eocdSignature: UInt32 = 0x06054b50
        let compressionStored: UInt16 = 0

        var zip = Data()
        var fileInfos: [(localOffset: Int, name: String, nameBytes: [UInt8], fileData: Data, crc: UInt32)] = []

        for i in 0..<fileCount
        {
            let fileData = UURandom.randomBytes(length: 1024).uuToHexString().data(using: .utf8) ?? Data()
            let name = "random_file_\(i).txt"
            let nameBytes = [UInt8](name.utf8)
            let crc = crc32(data: fileData)
            let localOffset = zip.count

            var header = Data()
            header.append(contentsOf: withUnsafeBytes(of: localFileHeaderSignature.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [20, 0] as [UInt8])
            header.append(contentsOf: [0, 0] as [UInt8])
            header.append(contentsOf: withUnsafeBytes(of: compressionStored.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0, 0, 0] as [UInt8])
            header.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt16(nameBytes.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0] as [UInt8])
            header.append(contentsOf: nameBytes)
            zip.append(header)
            zip.append(fileData)
            fileInfos.append((localOffset, name, nameBytes, fileData, crc))
        }

        let centralDirOffset = zip.count
        for info in fileInfos
        {
            var central = Data()
            central.append(contentsOf: withUnsafeBytes(of: centralFileHeaderSignature.littleEndian) { [UInt8]($0) })
            central.append(contentsOf: [0, 0, 20, 0] as [UInt8])  // version made by, version needed
            central.append(contentsOf: [0, 0] as [UInt8])           // flags
            central.append(contentsOf: withUnsafeBytes(of: compressionStored.littleEndian) { [UInt8]($0) })
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])    // mod time, mod date
            central.append(contentsOf: withUnsafeBytes(of: info.crc.littleEndian) { [UInt8]($0) })
            central.append(contentsOf: withUnsafeBytes(of: UInt32(info.fileData.count).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: withUnsafeBytes(of: UInt32(info.fileData.count).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: withUnsafeBytes(of: UInt16(info.nameBytes.count).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])    // extra length, file comment length
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])    // disk number start, internal attr
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])    // external attr
            central.append(contentsOf: withUnsafeBytes(of: UInt32(info.localOffset).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: info.nameBytes)
            zip.append(central)
        }
        let centralDirSize = zip.count - centralDirOffset

        var eocd = Data()
        eocd.append(contentsOf: withUnsafeBytes(of: eocdSignature.littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: [0, 0, 0, 0] as [UInt8])  // disk number, disk with central dir
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(fileCount).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(fileCount).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirSize).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirOffset).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: [0, 0] as [UInt8])  // comment length
        zip.append(eocd)
        return zip
    }

    /// Creates ZIP data using the data descriptor format (bit 3 set, sizes 0 in local header),
    /// with a proper central directory and EOCD so uuUnzip (central-directory-based) can extract it.
    private func makeZipDataWithDataDescriptor(fileCount: Int) -> Data
    {
        let localFileHeaderSignature: UInt32 = 0x04034b50
        let centralFileHeaderSignature: UInt32 = 0x02014b50
        let dataDescriptorSignature: UInt32 = 0x08074b50
        let eocdSignature: UInt32 = 0x06054b50
        let compressionStored: UInt16 = 0
        let flagDataDescriptor: UInt16 = 8

        var zip = Data()
        var fileInfos: [(localOffset: Int, name: String, nameBytes: [UInt8], fileData: Data, crc: UInt32)] = []

        for i in 0..<fileCount
        {
            let fileData = "streaming entry \(i)\n".data(using: .utf8) ?? Data()
            let name = "stream_file_\(i).txt"
            let nameBytes = [UInt8](name.utf8)
            let crc = crc32(data: fileData)
            let localOffset = zip.count

            var header = Data()
            header.append(contentsOf: withUnsafeBytes(of: localFileHeaderSignature.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [20, 0] as [UInt8])
            header.append(contentsOf: withUnsafeBytes(of: flagDataDescriptor.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: compressionStored.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0, 0, 0] as [UInt8])
            header.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0, 0, 0] as [UInt8])
            header.append(contentsOf: [0, 0, 0, 0] as [UInt8])
            header.append(contentsOf: withUnsafeBytes(of: UInt16(nameBytes.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0] as [UInt8])
            header.append(contentsOf: nameBytes)
            zip.append(header)
            zip.append(fileData)
            var descriptor = Data()
            descriptor.append(contentsOf: withUnsafeBytes(of: dataDescriptorSignature.littleEndian) { [UInt8]($0) })
            descriptor.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { [UInt8]($0) })
            descriptor.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { [UInt8]($0) })
            descriptor.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { [UInt8]($0) })
            zip.append(descriptor)
            fileInfos.append((localOffset, name, nameBytes, fileData, crc))
        }

        let centralDirOffset = zip.count
        for info in fileInfos
        {
            var central = Data()
            central.append(contentsOf: withUnsafeBytes(of: centralFileHeaderSignature.littleEndian) { [UInt8]($0) })
            central.append(contentsOf: [0, 0, 20, 0] as [UInt8])
            central.append(contentsOf: withUnsafeBytes(of: flagDataDescriptor.littleEndian) { [UInt8]($0) })  // bit 3 set
            central.append(contentsOf: withUnsafeBytes(of: compressionStored.littleEndian) { [UInt8]($0) })
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])
            central.append(contentsOf: withUnsafeBytes(of: info.crc.littleEndian) { [UInt8]($0) })
            central.append(contentsOf: withUnsafeBytes(of: UInt32(info.fileData.count).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: withUnsafeBytes(of: UInt32(info.fileData.count).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: withUnsafeBytes(of: UInt16(info.nameBytes.count).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])    // extra length, file comment length
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])    // disk number start, internal attr
            central.append(contentsOf: [0, 0, 0, 0] as [UInt8])   // external attr
            central.append(contentsOf: withUnsafeBytes(of: UInt32(info.localOffset).littleEndian) { [UInt8]($0) })
            central.append(contentsOf: info.nameBytes)
            zip.append(central)
        }
        let centralDirSize = zip.count - centralDirOffset

        var eocd = Data()
        eocd.append(contentsOf: withUnsafeBytes(of: eocdSignature.littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: [0, 0, 0, 0] as [UInt8])
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(fileCount).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(fileCount).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirSize).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirOffset).littleEndian) { [UInt8]($0) })
        eocd.append(contentsOf: [0, 0] as [UInt8])
        zip.append(eocd)
        return zip
    }

    /// CRC-32 (standard polynomial, table-based). iOS/macOS compatible.
    private func crc32(data: Data) -> UInt32
    {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data
        {
            crc = (crc >> 8) ^ crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return crc ^ 0xFFFF_FFFF
    }
    
    
    func readGZippedJsonFile(_ fileName: String) -> Data?
    {
        guard let fileUrl = Bundle.module.url(forResource: fileName, withExtension: "json.gz") else
        {
            NSLog("Unable to load file from bundle")
            return nil
        }
        
        guard let zippedData = try? Data(contentsOf: fileUrl) else
        {
            NSLog("Unable to create data from file")
            return nil
        }
        
        guard let data = try? zippedData.gunzipped() else
        {
            NSLog("Unable to unzip data from file")
            return nil
        }
        
        NSLog("Loaded data from file: \(String(data: data, encoding: .utf8) ?? "Unable to convert data to string")")
        
        return data
    }
    
    func readBundleFile(fileName: String, fileExtension: String) -> Data?
    {
        guard let fileUrl = Bundle.module.url(forResource: fileName, withExtension: fileExtension) else
        {
            NSLog("Unable to load file from bundle")
            return nil
        }
        
        guard let rawData = try? Data(contentsOf: fileUrl) else
        {
            NSLog("Unable to create data from file")
            return nil
        }
        
        NSLog("Loaded data from file: \(String(data: rawData, encoding: .utf8) ?? "Unable to convert data to string")")
        
        return rawData
    }
}

import Foundation
import zlib

extension Data
{
    func gunzipped() throws -> Data
    {
        guard !self.isEmpty else { return self }

        var stream = z_stream()
        var status: Int32

        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: (self as NSData).bytes.bindMemory(to: Bytef.self, capacity: self.count))
        stream.avail_in = uInt(self.count)

        // 16 + MAX_WBITS enables gzip header decoding
        status = inflateInit2_(&stream, 16 + MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else
        {
            throw NSError(domain: "ZlibError", code: Int(status), userInfo: nil)
        }

        defer
        {
            inflateEnd(&stream)
        }

        var output = Data()
        let chunkSize = 32_768

        repeat
        {
            var buffer = [UInt8](repeating: 0, count: chunkSize)

            let written: Int = try buffer.withUnsafeMutableBytes
            { (outputPtr: UnsafeMutableRawBufferPointer) in
                
                guard let outBase = outputPtr.baseAddress?.assumingMemoryBound(to: Bytef.self) else
                {
                    throw NSError(domain: "BufferError", code: -1, userInfo: nil)
                }

                stream.next_out = outBase
                stream.avail_out = uInt(chunkSize)

                status = inflate(&stream, Z_NO_FLUSH)

                if status != Z_OK && status != Z_STREAM_END
                {
                    throw NSError(domain: "ZlibError", code: Int(status), userInfo: nil)
                }

                return chunkSize - Int(stream.avail_out)
            }

            output.append(buffer, count: written)

        }
        while status != Z_STREAM_END

        return output
    }
}

// MARK: - CRC-32 table (ZIP standard polynomial)

private let crc32Table: [UInt32] = (0..<256).map { i in
    var c = UInt32(i)
    for _ in 0..<8
    {
        c = (c & 1) == 1 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
    }
    return c
}

