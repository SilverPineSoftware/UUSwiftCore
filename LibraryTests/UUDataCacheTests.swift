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

    override func setUp() async throws
    {
        try await super.setUp()
        cacheDirectory = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("UUDataCacheTests-\(UUID().uuidString)")
        cache = UUDataCache(cacheLocation: cacheDirectory, contentExpiration: 3600)
    }

    override func tearDown() async throws
    {
        if let cache
        {
            await cache.clearCache()
        }

        if !cacheDirectory.isEmpty
        {
            try? FileManager.default.removeItem(atPath: cacheDirectory)
        }

        cache = nil
        try await super.tearDown()
    }

    // MARK: - data(for:)

    func test_data_returnsNilForMissingKey() async
    {
        let result = await cache.data(for: uniqueKey("missing"))
        XCTAssertNil(result)
    }

    func test_setAndGetData_roundTripsPayload() async
    {
        let key = uniqueKey("round-trip")
        let payload = Data((0..<512).map { UInt8($0 % 256) })

        await cache.set(data: payload, for: key)
        let loaded = await cache.data(for: key)

        XCTAssertEqual(loaded, payload)
    }

    func test_setData_overwritesExistingValue() async
    {
        let key = uniqueKey("overwrite")
        let original = Data("original".utf8)
        let updated = Data("updated-bytes".utf8)

        await cache.set(data: original, for: key)
        await cache.set(data: updated, for: key)

        let actual = await cache.data(for: key)
        XCTAssertEqual(actual, updated)
    }

    func test_multipleKeys_storeIndependently() async
    {
        let keyA = uniqueKey("a")
        let keyB = uniqueKey("b")
        let dataA = Data("alpha".utf8)
        let dataB = Data("beta".utf8)

        await cache.set(data: dataA, for: keyA)
        await cache.set(data: dataB, for: keyB)

        let loadedA = await cache.data(for: keyA)
        let loadedB = await cache.data(for: keyB)
        XCTAssertEqual(loadedA, dataA)
        XCTAssertEqual(loadedB, dataB)
    }

    func test_data_supportsUnsafeUrlLikeKey() async
    {
        let key = uniqueKey("http://example.com/image.png?size=large&format=png")
        let payload = Data([0x01, 0x02, 0x03])

        await cache.set(data: payload, for: key)

        let exists = await cache.dataExists(for: key)
        let actual = await cache.data(for: key)
        XCTAssertTrue(exists)
        XCTAssertEqual(actual, payload)
    }

    // MARK: - dataExists(for:)

    func test_dataExists_isFalseForMissingKey() async
    {
        let exists = await cache.dataExists(for: uniqueKey("absent"))
        XCTAssertFalse(exists)
    }

    func test_dataExists_isTrueAfterSet() async
    {
        let key = uniqueKey("exists")
        await cache.set(data: Data("payload".utf8), for: key)

        let exists = await cache.dataExists(for: key)
        XCTAssertTrue(exists)
    }

    // MARK: - removeData(for:)

    func test_removeData_removesStoredBytes() async
    {
        let key = uniqueKey("remove")
        await cache.set(data: Data("temporary".utf8), for: key)

        await cache.removeData(for: key)

        let exists = await cache.dataExists(for: key)
        let loaded = await cache.data(for: key)
        XCTAssertFalse(exists)
        XCTAssertNil(loaded)
    }

    // MARK: - metaData

    func test_setData_writesTimestampMetadata() async
    {
        let key = uniqueKey("timestamp")
        await cache.set(data: Data("x".utf8), for: key)

        let md = await cache.metaData(for: key)

        XCTAssertNotNil(md[UUDataCache.MetaDataKeys.timestamp] as? Date)
    }

    func test_setMetaData_roundTripsCustomValues() async
    {
        let key = uniqueKey("metadata")
        await cache.set(metaData: ["color": "red", "count": 3], for: key)

        let md = await cache.metaData(for: key)

        XCTAssertEqual(md["color"] as? String, "red")
        XCTAssertEqual(md["count"] as? Int, 3)
    }

    func test_setData_preservesExistingCustomMetadata() async
    {
        let key = uniqueKey("preserve-metadata")
        await cache.set(metaData: ["tag": "keep-me"], for: key)
        await cache.set(data: Data("payload".utf8), for: key)

        let md = await cache.metaData(for: key)

        XCTAssertEqual(md["tag"] as? String, "keep-me")
        XCTAssertNotNil(md[UUDataCache.MetaDataKeys.timestamp] as? Date)
    }

    // MARK: - expiration

    func test_isDataExpired_isFalseForFreshData() async
    {
        let key = uniqueKey("fresh")
        cache.contentExpirationLength = 3600
        await cache.set(data: Data("fresh".utf8), for: key)

        let isExpired = await cache.isDataExpired(for: key)
        XCTAssertFalse(isExpired)
    }

    func test_isDataExpired_isTrueWhenTimestampIsOld() async
    {
        let key = uniqueKey("expired")
        cache.contentExpirationLength = 60
        await cache.set(data: Data("stale".utf8), for: key)

        var md = await cache.metaData(for: key)
        md[UUDataCache.MetaDataKeys.timestamp] = Date(timeIntervalSince1970: 0)
        await cache.set(metaData: md, for: key)

        let isExpired = await cache.isDataExpired(for: key)
        XCTAssertTrue(isExpired)
    }

    func test_data_removesExpiredEntryOnRead() async
    {
        let key = uniqueKey("auto-purge-on-read")
        cache.contentExpirationLength = 60
        await cache.set(data: Data("old".utf8), for: key)

        var md = await cache.metaData(for: key)
        md[UUDataCache.MetaDataKeys.timestamp] = Date(timeIntervalSince1970: 0)
        await cache.set(metaData: md, for: key)

        let loaded = await cache.data(for: key)
        let exists = await cache.dataExists(for: key)
        XCTAssertNil(loaded)
        XCTAssertFalse(exists)
    }

    func test_dataExpirationInterval_aliasesContentExpirationLength() async
    {
        cache.dataExpirationInterval = 123
        XCTAssertEqual(cache.contentExpirationLength, 123)

        cache.contentExpirationLength = 456
        XCTAssertEqual(cache.dataExpirationInterval, 456)
    }

    func test_purgeExpiredData_removesOnlyExpiredEntries() async
    {
        cache.contentExpirationLength = 60

        let freshKey = uniqueKey("fresh-purge")
        let expiredKey = uniqueKey("expired-purge")
        await cache.set(data: Data("fresh".utf8), for: freshKey)
        await cache.set(data: Data("expired".utf8), for: expiredKey)

        var expiredMd = await cache.metaData(for: expiredKey)
        expiredMd[UUDataCache.MetaDataKeys.timestamp] = Date(timeIntervalSince1970: 0)
        await cache.set(metaData: expiredMd, for: expiredKey)

        await cache.purgeExpiredData()

        let freshExists = await cache.dataExists(for: freshKey)
        let expiredExists = await cache.dataExists(for: expiredKey)
        XCTAssertTrue(freshExists)
        XCTAssertFalse(expiredExists)
    }

    // MARK: - listKeys / clearCache

    func test_listKeys_returnsDiskFileNamesAfterWrite() async
    {
        let key = uniqueKey("listed")
        await cache.set(data: Data("listed".utf8), for: key)

        let keys = await cache.listKeys()

        XCTAssertEqual(keys.count, 1)
        XCTAssertFalse(keys[0].isEmpty)
    }

    func test_clearCache_removesAllStoredFiles() async
    {
        for index in 0..<5
        {
            await cache.set(data: Data("item-\(index)".utf8), for: uniqueKey("bulk-\(index)"))
        }

        let keysBeforeClear = await cache.listKeys()
        XCTAssertEqual(keysBeforeClear.count, 5)

        await cache.clearCache()

        let keysAfterClear = await cache.listKeys()
        XCTAssertEqual(keysAfterClear.count, 0)
    }

    // MARK: - diskCacheURL / moveIntoCache

    func test_diskCacheURL_pointsInsideCacheFolder() async
    {
        let key = uniqueKey("disk-url")
        await cache.set(data: Data("x".utf8), for: key)

        guard let url = cache.diskCacheURL(for: key) else
        {
            XCTFail("Expected disk cache URL")
            return
        }

        XCTAssertTrue(url.path.hasPrefix(cacheDirectory))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_moveIntoCache_movesLocalFileIntoCache() async throws
    {
        let key = uniqueKey("move-in")
        let payload = Data("moved-bytes".utf8)
        let sourceURL = URL(fileURLWithPath: cacheDirectory)
            .appendingPathComponent("source-\(UUID().uuidString).dat")
        try payload.write(to: sourceURL)

        await cache.moveIntoCache(localData: sourceURL, for: key)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))

        let loaded = await cache.data(for: key)
        let exists = await cache.dataExists(for: key)
        XCTAssertEqual(loaded, payload)
        XCTAssertTrue(exists)
    }

    // MARK: - defaultCacheFolder

    func test_defaultCacheFolder_returnsNonEmptyPath() async
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
