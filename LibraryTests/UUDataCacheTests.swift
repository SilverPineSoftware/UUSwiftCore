//
//  UUDataCacheTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/8/26.
//

import XCTest
@testable import UUSwiftCore

final class UUDataCacheTests: XCTestCase
{
    private var cacheDirectory: String = ""
    private var cache: UUDataCache!

    override func setUp()
    {
        super.setUp()
        cacheDirectory = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("UUDataCacheTests-\(UUID().uuidString)")
        cache = UUDataCache(cacheLocation: cacheDirectory, contentExpiration: 3600)
    }

    override func tearDown()
    {
        cache?.clearCache()
        if !cacheDirectory.isEmpty
        {
            try? FileManager.default.removeItem(atPath: cacheDirectory)
        }
        cache = nil
        super.tearDown()
    }

    // MARK: - data(for:)

    func test_data_returnsNilForMissingKey()
    {
        let result = cache.data(for: uniqueKey("missing"))
        XCTAssertNil(result)
    }

    func test_setAndGetData_roundTripsPayload()
    {
        let key = uniqueKey("round-trip")
        let payload = Data((0..<512).map { UInt8($0 % 256) })

        cache.set(data: payload, for: key)
        let loaded = cache.data(for: key)

        XCTAssertEqual(loaded, payload)
    }

    func test_setData_overwritesExistingValue()
    {
        let key = uniqueKey("overwrite")
        let original = Data("original".utf8)
        let updated = Data("updated-bytes".utf8)

        cache.set(data: original, for: key)
        cache.set(data: updated, for: key)

        let actual = cache.data(for: key)
        XCTAssertEqual(actual, updated)
    }

    func test_multipleKeys_storeIndependently()
    {
        let keyA = uniqueKey("a")
        let keyB = uniqueKey("b")
        let dataA = Data("alpha".utf8)
        let dataB = Data("beta".utf8)

        cache.set(data: dataA, for: keyA)
        cache.set(data: dataB, for: keyB)

        let loadedA = cache.data(for: keyA)
        let loadedB = cache.data(for: keyB)
        XCTAssertEqual(loadedA, dataA)
        XCTAssertEqual(loadedB, dataB)
    }

    func test_data_supportsUnsafeUrlLikeKey()
    {
        let key = uniqueKey("http://example.com/image.png?size=large&format=png")
        let payload = Data([0x01, 0x02, 0x03])

        cache.set(data: payload, for: key)

        XCTAssertTrue(cache.dataExists(for: key))
        
        let actual = cache.data(for: key)
        XCTAssertEqual(actual, payload)
    }

    // MARK: - dataExists(for:)

    func test_dataExists_isFalseForMissingKey()
    {
        XCTAssertFalse(cache.dataExists(for: uniqueKey("absent")))
    }

    func test_dataExists_isTrueAfterSet()
    {
        let key = uniqueKey("exists")
        cache.set(data: Data("payload".utf8), for: key)

        XCTAssertTrue(cache.dataExists(for: key))
    }

    // MARK: - removeData(for:)

    func test_removeData_removesStoredBytes()
    {
        let key = uniqueKey("remove")
        cache.set(data: Data("temporary".utf8), for: key)

        cache.removeData(for: key)

        XCTAssertFalse(cache.dataExists(for: key))
        XCTAssertNil(cache.data(for: key))
    }

    // MARK: - metaData

    func test_setData_writesTimestampMetadata()
    {
        let key = uniqueKey("timestamp")
        cache.set(data: Data("x".utf8), for: key)

        let md = cache.metaData(for: key)

        XCTAssertNotNil(md[UUDataCache.MetaDataKeys.timestamp] as? Date)
    }

    func test_setMetaData_roundTripsCustomValues()
    {
        let key = uniqueKey("metadata")
        cache.set(metaData: ["color": "red", "count": 3], for: key)

        let md = cache.metaData(for: key)

        XCTAssertEqual(md["color"] as? String, "red")
        XCTAssertEqual(md["count"] as? Int, 3)
    }

    func test_setData_preservesExistingCustomMetadata()
    {
        let key = uniqueKey("preserve-metadata")
        cache.set(metaData: ["tag": "keep-me"], for: key)
        cache.set(data: Data("payload".utf8), for: key)

        let md = cache.metaData(for: key)

        XCTAssertEqual(md["tag"] as? String, "keep-me")
        XCTAssertNotNil(md[UUDataCache.MetaDataKeys.timestamp] as? Date)
    }

    // MARK: - expiration

    func test_isDataExpired_isFalseForFreshData()
    {
        let key = uniqueKey("fresh")
        cache.contentExpirationLength = 3600
        cache.set(data: Data("fresh".utf8), for: key)

        XCTAssertFalse(cache.isDataExpired(for: key))
    }

    func test_isDataExpired_isTrueWhenTimestampIsOld()
    {
        let key = uniqueKey("expired")
        cache.contentExpirationLength = 60
        cache.set(data: Data("stale".utf8), for: key)

        var md = cache.metaData(for: key)
        md[UUDataCache.MetaDataKeys.timestamp] = Date(timeIntervalSince1970: 0)
        cache.set(metaData: md, for: key)

        XCTAssertTrue(cache.isDataExpired(for: key))
    }

    func test_data_removesExpiredEntryOnRead()
    {
        let key = uniqueKey("auto-purge-on-read")
        cache.contentExpirationLength = 60
        cache.set(data: Data("old".utf8), for: key)

        var md = cache.metaData(for: key)
        md[UUDataCache.MetaDataKeys.timestamp] = Date(timeIntervalSince1970: 0)
        cache.set(metaData: md, for: key)

        let loaded = cache.data(for: key)
        let exists = cache.dataExists(for: key)
        XCTAssertNil(loaded)
        XCTAssertFalse(exists)
    }

    func test_dataExpirationInterval_aliasesContentExpirationLength()
    {
        cache.dataExpirationInterval = 123
        XCTAssertEqual(cache.contentExpirationLength, 123)

        cache.contentExpirationLength = 456
        XCTAssertEqual(cache.dataExpirationInterval, 456)
    }

    func test_purgeExpiredData_removesOnlyExpiredEntries()
    {
        cache.contentExpirationLength = 60

        let freshKey = uniqueKey("fresh-purge")
        let expiredKey = uniqueKey("expired-purge")
        cache.set(data: Data("fresh".utf8), for: freshKey)
        cache.set(data: Data("expired".utf8), for: expiredKey)

        var expiredMd = cache.metaData(for: expiredKey)
        expiredMd[UUDataCache.MetaDataKeys.timestamp] = Date(timeIntervalSince1970: 0)
        cache.set(metaData: expiredMd, for: expiredKey)

        cache.purgeExpiredData()

        XCTAssertTrue(cache.dataExists(for: freshKey))
        XCTAssertFalse(cache.dataExists(for: expiredKey))
    }

    // MARK: - listKeys / clearCache

    func test_listKeys_returnsDiskFileNamesAfterWrite()
    {
        let key = uniqueKey("listed")
        cache.set(data: Data("listed".utf8), for: key)

        let keys = cache.listKeys()

        XCTAssertEqual(keys.count, 1)
        XCTAssertFalse(keys[0].isEmpty)
    }

    func test_clearCache_removesAllStoredFiles()
    {
        for index in 0..<5
        {
            cache.set(data: Data("item-\(index)".utf8), for: uniqueKey("bulk-\(index)"))
        }

        let keysBeforeClear = cache.listKeys()
        XCTAssertEqual(keysBeforeClear.count, 5)

        cache.clearCache()

        let keysAfterClear = cache.listKeys()
        XCTAssertEqual(keysAfterClear.count, 0)
    }

    // MARK: - diskCacheURL / moveIntoCache

    func test_diskCacheURL_pointsInsideCacheFolder()
    {
        let key = uniqueKey("disk-url")
        cache.set(data: Data("x".utf8), for: key)

        guard let url = cache.diskCacheURL(for: key) else
        {
            XCTFail("Expected disk cache URL")
            return
        }

        XCTAssertTrue(url.path.hasPrefix(cacheDirectory))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_moveIntoCache_movesLocalFileIntoCache() throws
    {
        let key = uniqueKey("move-in")
        let payload = Data("moved-bytes".utf8)
        let sourceURL = URL(fileURLWithPath: cacheDirectory)
            .appendingPathComponent("source-\(UUID().uuidString).dat")
        try payload.write(to: sourceURL)

        cache.moveIntoCache(localData: sourceURL, for: key)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))

        let loaded = cache.data(for: key)
        let exists = cache.dataExists(for: key)
        XCTAssertEqual(loaded, payload)
        XCTAssertTrue(exists)
    }

    // MARK: - defaultCacheFolder

    func test_defaultCacheFolder_returnsNonEmptyPath()
    {
        let path = UUDataCache.defaultCacheFolder()

        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains("UUDataCache"))
    }

    // MARK: - helpers

    private func uniqueKey(_ label: String) -> String
    {
        "\(label)-\(UUID().uuidString)"
    }
}
