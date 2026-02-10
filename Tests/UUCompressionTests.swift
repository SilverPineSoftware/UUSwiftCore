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

    /// Creates ZIP data in memory (iOS/macOS compatible, no Process).
    /// Contains `fileCount` files: random_file_0.txt … random_file_N-1.txt,
    /// each with 1024 bytes of random hex string as UTF-8. Uses stored compression only.
    private func makeZipData(fileCount: Int) -> Data
    {
        var zip = Data()
        let localFileHeaderSignature: UInt32 = 0x04034b50
        let compressionStored: UInt16 = 0

        for i in 0..<fileCount
        {
            let fileData = UURandom.randomBytes(length: 1024).uuToHexString().data(using: .utf8) ?? Data()
            let name = "random_file_\(i).txt"
            let nameBytes = [UInt8](name.utf8)
            let crc = crc32(data: fileData)

            var header = Data()
            header.append(contentsOf: withUnsafeBytes(of: localFileHeaderSignature.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [20, 0] as [UInt8])           // version needed
            header.append(contentsOf: [0, 0] as [UInt8])            // flags
            header.append(contentsOf: withUnsafeBytes(of: compressionStored.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0, 0, 0] as [UInt8])      // mod time, mod date
            header.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt16(nameBytes.count).littleEndian) { [UInt8]($0) })
            header.append(contentsOf: [0, 0] as [UInt8])           // extra length
            header.append(contentsOf: nameBytes)
            zip.append(header)
            zip.append(fileData)
        }
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
