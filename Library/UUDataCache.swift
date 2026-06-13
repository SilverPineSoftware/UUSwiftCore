//  UUDataCache
//  Useful Utilities - UUDataCache is a lightweight facade for caching data.
//
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

import Foundation
import CoreData

fileprivate let LOG_TAG : String = "UUDataCache"

// UUDataCacheProtocol defines a lightweight interface for caching of data
// along with a meta data dictionary about each blob of data.
public protocol UUDataCacheProtocol
{
    func data(for key: String) async -> Data?
    func set(data: Data, for key: String) async
    
    func metaData(for key: String) async -> [String:Any]
    func set(metaData: [String:Any], for key: String) async
    
    func dataExists(for key: String) async -> Bool
    func isDataExpired(for key: String) async -> Bool
    
    func removeData(for key: String) async
    
    func clearCache() async
    func purgeExpiredData() async
    
    func listKeys() async -> [String]
}

// Default implementation of UUDataCacheProtocol.  Data objects are persisted
// in an NSCache backed by raw data files.
//
// Meta Data is persisted with CoreData
public class UUDataCache : NSObject, UUDataCacheProtocol
{
    ////////////////////////////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////////////////////////////
    public struct Constants
    {
        public static let defaultContentExpirationLength : TimeInterval = (60 * 60 * 24 * 30) // 30 days
    }
    
    public struct MetaDataKeys
    {
        public static let timestamp = "timestamp"
        public static let fileName = "fileName"
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // Class Data Memebers
    ////////////////////////////////////////////////////////////////////////////
    nonisolated(unsafe) public static let shared = UUDataCache()
    
    ////////////////////////////////////////////////////////////////////////////
    // Instance Data Memebers
    ////////////////////////////////////////////////////////////////////////////
    public var contentExpirationLength : TimeInterval = Constants.defaultContentExpirationLength
    
    private var cacheFolder : String = ""
    
    ////////////////////////////////////////////////////////////////////////////
    // Initialization
    ////////////////////////////////////////////////////////////////////////////
    required public init(cacheLocation : String = UUDataCache.defaultCacheFolder(),
                       contentExpiration: TimeInterval = Constants.defaultContentExpirationLength)
    {
        super.init()
        
        cacheFolder = cacheLocation
        contentExpirationLength = contentExpiration
        UUDataCache.createFolderIfNeeded(cacheFolder)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // UUDataCacheProtocol Implementation
    ////////////////////////////////////////////////////////////////////////////
    public func data(for key: String) async -> Data?
    {
        await removeIfExpired(for: key)
        
        let cached = await loadFromDisk(for: key)
        return cached
    }
    
    public func set(data: Data, for key: String) async
    {
        await saveToDisk(data: data, for: key)
        
        var md = await metaData(for: key)
        md[MetaDataKeys.timestamp] = Date()
        await set(metaData: md, for: key)
    }
    
    public func moveIntoCache(localData: URL, for key: String) async
    {
        guard let pathUrl = diskCacheURL(for: key) else
        {
            return
        }
        
        do
        {
            let fm = FileManager.default
            try fm.moveItem(at: localData, to: pathUrl)
            
            var md = await metaData(for: key)
            md[MetaDataKeys.timestamp] = Date()
            await set(metaData: md, for: key)
        }
        catch (let err)
        {
            UULog.error(tag: LOG_TAG, message: "Error moving URL into cache: \(String(describing: err))")
        }
    }
    
    public func metaData(for key: String) async -> [String:Any]
    {
        return UUDataCacheDb.shared.metaData(for: key)
    }
    
    public func set(metaData: [String:Any], for key: String) async
    {
        UUDataCacheDb.shared.setMetaData(metaData, for: key)
    }
    
    public func dataExists(for key: String) async -> Bool
    {
        return await dataExistsOnDisk(key: key)
    }
    
    public func isDataExpired(for key: String) async -> Bool
    {
        let md = await metaData(for: key)
        let timestamp = md[MetaDataKeys.timestamp] as? Date
        if (timestamp != nil)
        {
            let elapsed = Date().timeIntervalSince(timestamp!)
            return (elapsed > contentExpirationLength)
        }
        
        return false
    }
    
    public func removeData(for key: String) async
    {
        UUDataCacheDb.shared.clearMetaData(for: key)
        await removeFile(for: key)
    }
    
    public func clearCache() async
    {
        let fm = FileManager.default
        
        do
        {
            try fm.removeItem(atPath: cacheFolder)
        }
        catch (let err)
        {
            UULog.error(tag: LOG_TAG, message: "Error creating cache path: \(String(describing: err))")
        }
        
        UUDataCache.createFolderIfNeeded(cacheFolder)
        
        UUDataCacheDb.shared.clearAllMetaData()
    }
    
    public func purgeExpiredData() async
    {
        let keys = UUDataCacheDb.shared.logicalKeys()
        
        for key in keys
        {
            await removeIfExpired(for: key)
        }
    }
    
    public func listKeys() async -> [String]
    {
        var contents : [String] = []
        
        do
        {
            contents = try FileManager.default.contentsOfDirectory(atPath: cacheFolder)
        }
        catch (_)
        {
            //UUDebugLog("Error fetching contents of directory: %@", String(describing: err))
        }
        
        return contents
    }
    
    public var dataExpirationInterval : TimeInterval
    {
        get
        {
            return contentExpirationLength
        }
        
        set
        {
            contentExpirationLength = newValue
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // Private Implementation
    ////////////////////////////////////////////////////////////////////////////
    public static func defaultCacheFolder() -> String
    {
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).last!
        let path = (cachePath as NSString).appendingPathComponent("UUDataCache")
        return path
    }
    
    private static func createFolderIfNeeded(_ folder: String)
    {
        let fm = FileManager.default
        if (!fm.fileExists(atPath: folder))
        {
            do
            {
                try fm.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
            }
            catch (let err)
            {
                UULog.error(tag: LOG_TAG, message: "Error creating folder: \(String(describing: err)))")
            }
        }
    }
    
    public func diskCacheURL(for key: String) -> URL?
    {
        if let fileName = UUDataCacheDb.shared.fileName(for: key)
        {
            let path = (cacheFolder as NSString).appendingPathComponent(fileName)
            let pathUrl = URL(fileURLWithPath: path)
            return pathUrl
        }
        
        return nil
    }
    
    private func removeIfExpired(for key: String) async
    {
        if (await isDataExpired(for: key))
        {
            await removeData(for: key)
        }
    }
    
    private func loadFromDisk(for key: String) async -> Data?
    {
        var data : Data? = nil
        
        guard let pathUrl = diskCacheURL(for: key) else
        {
            return nil
        }
        
        do
        {
            data = try Data(contentsOf: pathUrl)
        }
        catch (_)
        {
            //UUDebugLog("Error loading data: %@", String(describing: err))
        }
        
        return data
    }
        
    private func removeFile(for key: String) async
    {
        guard let pathUrl = diskCacheURL(for: key) else
        {
            return
        }
        
        do
        {
            try FileManager.default.removeItem(at: pathUrl)
        }
        catch (_)
        {
            //UUDebugLog("Error removing file: %@", String(describing: err))
        }
    }
    
    private func saveToDisk(data: Data, for key: String) async
    {
        guard let pathUrl = diskCacheURL(for: key) else
        {
            return
        }
        
        do
        {
            try data.write(to: pathUrl, options: .atomic)
        }
        catch (let err)
        {
            UULog.error(tag: LOG_TAG, message: "Error saving data: \(String(describing: err))")
        }
    }
       
    private func dataExistsOnDisk(key: String) async -> Bool
    {
        guard let pathUrl = diskCacheURL(for: key) else
        {
            return false
        }
        
        return FileManager.default.fileExists(atPath:pathUrl.path)
    }
    
}


private class UUDataCacheDb
{
	private static let cacheKeyName = "UUDataCacheDb"
    nonisolated(unsafe) static let shared = UUDataCacheDb()
	
    let mutex = NSRecursiveLock()
	var metaData : [String : Any] = [:]
	
	init()
    {
		if let data = UserDefaults.standard.object(forKey: UUDataCacheDb.cacheKeyName) as? [String : Any]
        {
            mutex.lock()
            defer
            {
                mutex.unlock()
            }

            self.metaData = data
		}
	}
    
    public func metaData(for key: String) -> [String:Any]
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

        if let dictionary = self.metaData[key] as? [String:Any]
        {
            let copy = dictionary
            return copy
        }
        else
        {
            var md : [String : Any] = [:]
            md[UUDataCache.MetaDataKeys.fileName] = UUID().uuidString
            md[UUDataCache.MetaDataKeys.timestamp] = Date()
            self.metaData[key] = md

            let copy = md
            return copy
        }
        
    }
    
    public func fileName(for key: String) -> String?
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

        let metaData = self.metaData(for: key)
        return metaData[UUDataCache.MetaDataKeys.fileName] as? String
    }
    
    public func setMetaData(_ metaData: [String:Any], for key: String)
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

        self.metaData[key] = metaData
        self.saveCurrentMetaData()
    }
    
    public func clearMetaData(for key: String)
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

        self.metaData.removeValue(forKey: key)
        self.saveCurrentMetaData()
    }
    
    public func clearAllMetaData()
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

		UserDefaults.standard.removeObject(forKey: UUDataCacheDb.cacheKeyName)
        self.metaData = [:]
    }

    func logicalKeys() -> [String]
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

        return Array(metaData.keys)
    }

	private func saveCurrentMetaData()
    {
        mutex.lock()
        defer
        {
            mutex.unlock()
        }

        UserDefaults.standard.setValue(self.metaData, forKey: UUDataCacheDb.cacheKeyName)
	}
}



