//
//  UUCoreDataTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 8/2/25.
//

import XCTest
import CoreData
@testable import UUSwiftCore  // Replace with your module name if different

final class UUCoreDataTests: XCTestCase
{
    private func createTestModel() -> NSManagedObjectModel
    {
        let model = NSManagedObjectModel()
        
        model.entities.append(PlayerEntity.entityDescription())
        
        return model
    }
    
    // MARK: – Helpers

    /// A dummy model name that does *not* exist in the bundle
    private let nonexistentModelName = "ModelThatDoesNotExist"

    /// Resets/opens a stack with a unique SQLite store name, then runs `work` on a background context.
    private func performOnPlayerStack(
        storeLabel: String,
        work: @escaping (NSManagedObjectContext) -> Void
    )
    {
        let model = createTestModel()
        let stack = UUCoreDataStack(
            modelFileName: storeLabel,
            model: model,
            storeType: NSSQLiteStoreType
        )

        let resetExp = expectation(description: "reset \(storeLabel)")
        stack.reset { error in
            XCTAssertNil(error, "Reset failed")
            resetExp.fulfill()
        }
        waitForExpectations(timeout: 2)

        let openExp = expectation(description: "open \(storeLabel)")
        stack.open { error in
            XCTAssertNil(error, "Open failed")
            openExp.fulfill()
        }
        waitForExpectations(timeout: 2)

        let taskExp = expectation(description: "background \(storeLabel)")
        stack.performBackgroundTask { context in
            work(context)
        } completion: { _ in
            taskExp.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    // MARK: - init
    
    func testInitWithModel()
    {
        // Given
        let modelName = "TestModel"
        let testModel = NSManagedObjectModel()
        let customStoreType = "CustomStoreType"
        let autoMigrate = false
        let folder: FileManager.SearchPathDirectory = .cachesDirectory

        // When
        let stack = UUCoreDataStack(
            modelFileName: modelName,
            model: testModel,
            storeType: customStoreType,
            autoMigrate: autoMigrate,
            folder: folder
        )

        // Then
        // modelBundle should be nil when initializing with a concrete model
        XCTAssertNil(stack.modelBundle)

        // modelFileName
        XCTAssertEqual(stack.modelFileName, modelName)

        // model
        XCTAssert(stack.model === testModel,
                  "Expected stack.model to be the same instance passed in")

        // storeTye (note the property is named `storeTye`)
        XCTAssertEqual(stack.storeTye, customStoreType)

        // autoMigrate
        XCTAssertEqual(stack.autoMigrate, autoMigrate)

        // folder
        XCTAssertEqual(stack.folder, folder)
        
        // Store File Name
        XCTAssertEqual(stack.storeFileName, "\(modelName).sqlite")
        
        // Store Folder
        XCTAssertNotNil(stack.storeURL)
    }

    func testInitWithBundle()
    {
        // Given
        let modelName = "AnotherModel"
        let testBundle = Bundle(for: type(of: self))
        let defaultStoreType = NSSQLiteStoreType
        let autoMigrate = true
        let folder: FileManager.SearchPathDirectory = .applicationSupportDirectory

        // When
        let stack = UUCoreDataStack(
            modelFileName: modelName,
            modelBundle: testBundle,
            storeType: defaultStoreType,
            autoMigrate: autoMigrate,
            folder: folder
        )

        // Then
        // modelBundle should be set to the bundle passed in
        XCTAssertEqual(stack.modelBundle, testBundle)

        // modelFileName
        XCTAssertEqual(stack.modelFileName, modelName)

        // model should be nil until loaded
        XCTAssertNil(stack.model)

        // storeTye
        XCTAssertEqual(stack.storeTye, defaultStoreType)

        // autoMigrate
        XCTAssertEqual(stack.autoMigrate, autoMigrate)

        // folder
        XCTAssertEqual(stack.folder, folder)
        
        // Store File Name
        XCTAssertEqual(stack.storeFileName, "\(modelName).sqlite")
        
        // Store Folder
        XCTAssertNotNil(stack.storeURL)
    }
    
    // MARK: – storeFileName / storeURL

    func testStoreFileNameEndsWithSQLite()
    {
        let stack = UUCoreDataStack(modelFileName: "MyTestModel",
                                    storeType: NSInMemoryStoreType)
        XCTAssertEqual(stack.storeFileName, "MyTestModel.sqlite")
    }

    func testStoreURLContainsStoreFileName()
    {
        let stack = UUCoreDataStack(modelFileName: "AnotherModel",
                                    storeType: NSInMemoryStoreType)
        let url = stack.storeURL
        XCTAssertEqual(url.lastPathComponent, "AnotherModel.sqlite")
    }

    // MARK: – reset()

    func testResetWithoutExistingFileSucceeds()
    {
        let stack = UUCoreDataStack(modelFileName: "Whatever",
                                    storeType: NSInMemoryStoreType)
        let expectation = self.expectation(description: "reset completion")

        stack.reset
        { error in
            // No file existed, so reset should silently succeed without error
            XCTAssertNil(error)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
    
    func testResetWithExistingFileRemovesFile()
    {
        // Given
        let modelName = "ExistingFileModel"
        let stack = UUCoreDataStack(
            modelFileName: modelName,
            storeType: NSSQLiteStoreType
        )
        
        let fileURL = stack.storeURL

        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create a dummy file at the store URL
        let dummyData = Data([0x00])
        FileManager.default.createFile(atPath: fileURL.path, contents: dummyData, attributes: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Dummy store file should exist before reset")

        // When
        let exp = expectation(description: "reset completion for existing file")
        stack.reset
        { error in
            // Then
            XCTAssertNil(error, "Reset should not error when deleting existing file")
            XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Store file should be removed by reset()")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
    
    func testResetFailsWhenFileIsImmutable()
    {
        // Given
        let modelName = "ImmutableFileModel"
        let stack = UUCoreDataStack(
            modelFileName: modelName,
            storeType: NSSQLiteStoreType
        )
        var fileURL = stack.storeURL
        
        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create a dummy file at the store URL
        let dummyData = Data([0x00])
        FileManager.default.createFile(atPath: fileURL.path, contents: dummyData, attributes: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Dummy store file should exist before reset")

        // Make the file immutable so deletion fails
        var values = URLResourceValues()
        values.isUserImmutable = true
        try? fileURL.setResourceValues(values)

        // When
        let exp = expectation(description: "reset fails due to immutable file")
        stack.reset
        { error in
            // Then
            XCTAssertNotNil(error, "Reset should fail when file cannot be deleted")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    // MARK: – open(completion:)
    
    func testOpenWithExplicitBundleInitFailsWhenModelMissing()
    {
        // Given: a bundle (the test bundle) that has no model named "NonexistentModel.momd"
        let stack = UUCoreDataStack(
            modelFileName: "NonexistentModel",
            modelBundle: Bundle(for: type(of: self)),
            storeType: NSSQLiteStoreType
        )
        
        let exp = expectation(description: "open completion for missing explicit‐bundle model")

        // When
        stack.open
        { error in
            // Then
            XCTAssertNotNil(error, "Expected an error when the model can't be found in the given bundle")
            let nsErr = error! as NSError
            XCTAssertEqual(nsErr.domain, UUCoreDataErrorDomain)
            XCTAssertEqual(nsErr.code, UUCoreDataErrorCode.modelFileNotFound.rawValue)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testOpenWithNonexistentModelReturnsModelNotFoundError()
    {
        let stack = UUCoreDataStack(modelFileName: nonexistentModelName,
                                    storeType: NSInMemoryStoreType)

        let expectation = self.expectation(description: "open completion")

        stack.open { error in
            XCTAssertNotNil(error, "Expected an error when the model is missing")

            let nsError = error! as NSError
            XCTAssertEqual(nsError.domain, UUCoreDataErrorDomain)
            XCTAssertEqual(nsError.code, UUCoreDataErrorCode.modelFileNotFound.rawValue)

            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
    
    func testOpenFailsUnableToLoadModelWhenMomdPresentButInvalid()
    {
        // Given: set up a temporary “bundle” with an empty .momd directory
        let modelName = "InvalidModel"
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let fakeBundleURL = tempDir.appendingPathComponent("Fake.bundle")
        
        // 1) Create the fake bundle directory
        try? FileManager.default.createDirectory(
            at: fakeBundleURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // 2) Write a minimal Info.plist so Bundle(path:) recognizes it
        let infoPlistURL = fakeBundleURL.appendingPathComponent("Info.plist")
        let emptyDict = NSDictionary()
        emptyDict.write(to: infoPlistURL, atomically: true)
        
        // 3) Inside that bundle, create an empty “InvalidModel.momd” folder
        let momdURL = fakeBundleURL.appendingPathComponent("\(modelName).momd")
        try? FileManager.default.createDirectory(
            at: momdURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Build the Bundle object
        guard let fakeBundle = Bundle(path: fakeBundleURL.path) else {
            XCTFail("Could not instantiate bundle at \(fakeBundleURL.path)")
            return
        }
        
        let stack = UUCoreDataStack(
            modelFileName: modelName,
            modelBundle: fakeBundle,
            storeType: NSSQLiteStoreType
        )
        
        let exp = expectation(description: "open completion for invalid .momd")
        
        // When
        stack.open
        { error in
            // Then
            XCTAssertNotNil(error, "Expected an error when .momd exists but is invalid")
            let nsErr = error! as NSError
            XCTAssertEqual(nsErr.domain, UUCoreDataErrorDomain)
            XCTAssertEqual(nsErr.code, UUCoreDataErrorCode.unableToLoadModel.rawValue)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testOpenFailsLoadPersistentStoresFailedWhenStoreURLIsDirectory()
    {
        // Given: a valid model but the store URL is a directory, causing persistent store load to fail
        let testModel = createTestModel()
        let stack = UUCoreDataStack(
            modelFileName: "TestModelDir",
            model: testModel,
            storeType: NSSQLiteStoreType
        )
        let storeURL = stack.storeURL

        // Create a directory at the store URL path
        try? FileManager.default.createDirectory(
            at: storeURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path),
                      "Directory should exist at storeURL before opening")

        let exp = expectation(description: "open completion when store URL is a directory")

        // When
        stack.open
        { error in
            // Then
            XCTAssertNotNil(error,
                            "Expected an error when loadPersistentStores fails due to storeURL being a directory")
            let nsErr = error! as NSError
            XCTAssertEqual(nsErr.domain, UUCoreDataErrorDomain)
            XCTAssertEqual(nsErr.code, UUCoreDataErrorCode.loadPersistentStoresFailed.rawValue)
            XCTAssertNotNil(nsErr.userInfo[NSUnderlyingErrorKey],
                            "Underlying error should be present in userInfo")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
    
    /// A fake NSPersistentStore subclass that always fails to load metadata.
    private class FailingStore: NSPersistentStore
    {
        override class func metadataForPersistentStore(with url: URL) throws -> [String : Any] {
            
            throw NSError(
              domain: "TestDomain",
              code: 1234,
              userInfo: [NSLocalizedDescriptionKey: "Stub metadata failure"]
            )
        }
        
        override func loadMetadata() throws {
            throw NSError(
                domain: "TestDomain",
                code: 5678,
                userInfo: [NSLocalizedDescriptionKey: "Stub loadMetadata failure"]
            )
        }
    }

    func testOpenWithRegisteredFailingStoreTypeInvokesLoadPersistentStoresFailed()
    {
        // Default apple behavior fails with a fatalError when an unregistered or unknown store type is used.

        // 1) Register your stub BEFORE creating the stack
        let bogusType = "UNREGISTERED_TYPE"
        NSPersistentStoreCoordinator.registerStoreClass(FailingStore.self, forStoreType: bogusType)

        // 2) Create a valid in‐memory model so loadModel() succeeds
        let model = createTestModel()
        let stack = UUCoreDataStack(
            modelFileName: "TestModel",
            model: model,
            storeType: bogusType,
            autoMigrate: true,
            folder: .cachesDirectory
        )
        
        let exp = expectation(description: "open completion for stub store")

        // 3) Call open(…) and assert you get your wrapped error
        stack.open
        { error in
            XCTAssertNotNil(error, "Expected loadPersistentStoresFailed")
            let nsErr = error! as NSError
            XCTAssertEqual(nsErr.domain, UUCoreDataErrorDomain)
            XCTAssertEqual(
                nsErr.code,
                UUCoreDataErrorCode.loadPersistentStoresFailed.rawValue
            )
        
            // And the underlying should be our stub’s error
            let underlying = nsErr.userInfo[NSUnderlyingErrorKey] as? NSError
            XCTAssertEqual(underlying?.domain, "TestDomain")
            XCTAssertEqual(underlying?.code, 5678)
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
    
    func testInsertAndFetchPlayerEntity()
    {
        // Arrange: Create stack with a fresh store
        let model = createTestModel()
        let stack = UUCoreDataStack(
            modelFileName: "InsertFetchModel",
            model: model,
            storeType: NSSQLiteStoreType
        )
        
        // Ensure clean state
        let resetExpectation = expectation(description: "Reset before insert")
        stack.reset { error in
            XCTAssertNil(error, "Reset should succeed before starting test")
            resetExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)
        
        let openExpectation = expectation(description: "Open stack")
        stack.open { error in
            XCTAssertNil(error, "Open should succeed")
            openExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        let taskExpectation = expectation(description: "Background task")
        stack.performBackgroundTask
        { context in
            
            // Act: Insert PlayerEntity
            let id = UUID()
            let player = PlayerEntity(context: context)
            player.identifier = id
            player.name = "Test Player"
            player.number = 99
            player.gamesPlayed = 42
            player.nickName = "Slugger"
            
            let saveError = context.uuSave()
            XCTAssertNil(saveError)
            
            // Fetch the entity back
            let fetchRequest: NSFetchRequest<PlayerEntity> = PlayerEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "identifier == %@", id as CVarArg)
            
            let fetchedResults = try? context.fetch(fetchRequest)
            
            // Assert: Validate fields
            XCTAssertEqual(fetchedResults?.count, 1)
            guard let fetchedPlayer = fetchedResults?.first else {
                XCTFail("Failed to fetch inserted PlayerEntity")
                return
            }
            
            XCTAssertEqual(fetchedPlayer.identifier, id)
            XCTAssertEqual(fetchedPlayer.name, "Test Player")
            XCTAssertEqual(fetchedPlayer.number, 99)
            XCTAssertEqual(fetchedPlayer.gamesPlayed, 42)
            XCTAssertEqual(fetchedPlayer.nickName, "Slugger")
            
        } completion:
        { error in
            taskExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5)
    }
    
    
    func testUUCreate()
    {
        // Arrange: Create stack with a fresh store
        let model = createTestModel()
        let stack = UUCoreDataStack(
            modelFileName: "InsertFetchModel",
            model: model,
            storeType: NSSQLiteStoreType
        )
        
        // Ensure clean state
        let resetExpectation = expectation(description: "Reset before insert")
        stack.reset { error in
            XCTAssertNil(error, "Reset should succeed before starting test")
            resetExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)
        
        let openExpectation = expectation(description: "Open stack")
        stack.open { error in
            XCTAssertNil(error, "Open should succeed")
            openExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        let taskExpectation = expectation(description: "Background task")
        stack.performBackgroundTask
        { context in
            
            let id = UUID()
            
            let player = Player(
                identifier: id,
                name: "A player",
                number: 44,
                gamesPlayed: 29,
                nickName: "hello")
            
            PlayerEntity.uuCreate(from: player, in: context)
            
            let saveError = context.uuSave()
            XCTAssertNil(saveError)
            
            // Fetch the entity back
            let fetchRequest: NSFetchRequest<PlayerEntity> = PlayerEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "identifier == %@", id as CVarArg)
            
            let fetchedResults = try? context.fetch(fetchRequest)
            
            // Assert: Validate fields
            XCTAssertEqual(fetchedResults?.count, 1)
            guard let fetchedPlayer = fetchedResults?.first else {
                XCTFail("Failed to fetch inserted PlayerEntity")
                return
            }
            
            XCTAssertEqual(fetchedPlayer.identifier, id)
            XCTAssertEqual(fetchedPlayer.name, "A player")
            XCTAssertEqual(fetchedPlayer.number, 44)
            XCTAssertEqual(fetchedPlayer.gamesPlayed, 29)
            XCTAssertEqual(fetchedPlayer.nickName, "hello")
            
        } completion:
        { error in
            taskExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5)
    }

    // MARK: - UUEntityModelConvertible uuCreate

    func test_uuCreate_returnValueMatchesPersistedRow()
    {
        performOnPlayerStack(storeLabel: "uuCreate_returnValue")
        { context in
            let id = UUID()
            let model = Player(
                identifier: id,
                name: "Returned",
                number: 7,
                gamesPlayed: 3,
                nickName: "nick")

            let created = PlayerEntity.uuCreate(from: model, in: context)
            XCTAssertEqual(created.identifier, id)
            XCTAssertEqual(created.name, "Returned")
            XCTAssertEqual(created.number, 7)
            XCTAssertEqual(created.gamesPlayed, 3)
            XCTAssertEqual(created.nickName, "nick")

            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            req.predicate = NSPredicate(format: "identifier == %@", id as CVarArg)
            let rows = try? context.fetch(req)
            XCTAssertEqual(rows?.count, 1)
            XCTAssertTrue(rows?.first === created)
        }
    }

    func test_uuCreate_withNilNickName()
    {
        performOnPlayerStack(storeLabel: "uuCreate_nilNick")
        { context in
            let id = UUID()
            let model = Player(
                identifier: id,
                name: "NoNick",
                number: 1,
                gamesPlayed: 0,
                nickName: nil)

            let created = PlayerEntity.uuCreate(from: model, in: context)
            XCTAssertNil(created.nickName)
            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            req.predicate = NSPredicate(format: "identifier == %@", id as CVarArg)
            let rows = try? context.fetch(req)
            XCTAssertEqual(rows?.first?.nickName, nil)
        }
    }

    func test_uuCreate_withAppContext_parameterSurvivesCall()
    {
        performOnPlayerStack(storeLabel: "uuCreate_appCtx")
        { context in
            let id = UUID()
            let model = Player(
                identifier: id,
                name: "Ctx",
                number: 2,
                gamesPlayed: 1,
                nickName: nil)

            var appContext: Any? = ["token": 42]
            _ = PlayerEntity.uuCreate(from: model, in: context, with: &appContext)
            XCTAssertNotNil(appContext)
            let dict = appContext as? [String: Int]
            XCTAssertEqual(dict?["token"], 42)

            XCTAssertNil(context.uuSave())
        }
    }

    func test_uuCreateArray_multipleModels_allInserted()
    {
        performOnPlayerStack(storeLabel: "uuCreateArray_multi")
        { context in
            let id1 = UUID(), id2 = UUID(), id3 = UUID()
            let models = [
                Player(identifier: id1, name: "A", number: 1, gamesPlayed: 10, nickName: "a"),
                Player(identifier: id2, name: "B", number: 2, gamesPlayed: 20, nickName: "b"),
                Player(identifier: id3, name: "C", number: 3, gamesPlayed: 30, nickName: nil),
            ]

            let created = PlayerEntity.uuCreateArray(from: models, in: context)
            XCTAssertEqual(created.count, 3)
            XCTAssertEqual(Set(created.map(\.identifier)), Set([id1, id2, id3]))

            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            let rows = try? context.fetch(req)
            XCTAssertEqual(rows?.count, 3)
        }
    }

    func test_uuCreateArray_empty_noObjects()
    {
        performOnPlayerStack(storeLabel: "uuCreateArray_empty")
        { context in
            let created = PlayerEntity.uuCreateArray(from: [], in: context)
            XCTAssertTrue(created.isEmpty)
            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            let rows = try? context.fetch(req)
            XCTAssertEqual(rows?.count, 0)
        }
    }

    func test_uuCreateArray_withAppContext()
    {
        performOnPlayerStack(storeLabel: "uuCreateArray_appCtx")
        { context in
            let models = [
                Player(identifier: UUID(), name: "X", number: 0, gamesPlayed: 0, nickName: nil),
            ]
            var appContext: Any? = "marker"
            let out = PlayerEntity.uuCreateArray(from: models, in: context, with: &appContext)
            XCTAssertEqual(out.count, 1)
            XCTAssertEqual(appContext as? String, "marker")
            XCTAssertNil(context.uuSave())
        }
    }

    // MARK: - UUEntityModelConvertible uuCreateSet

    func test_uuCreateSet_multipleModels_returnsSetAndPersistsAll()
    {
        performOnPlayerStack(storeLabel: "uuCreateSet_multi")
        { context in
            let id1 = UUID(), id2 = UUID(), id3 = UUID()
            let models = [
                Player(identifier: id1, name: "S1", number: 1, gamesPlayed: 1, nickName: "s"),
                Player(identifier: id2, name: "S2", number: 2, gamesPlayed: 2, nickName: nil),
                Player(identifier: id3, name: "S3", number: 3, gamesPlayed: 3, nickName: "t"),
            ]

            let created = PlayerEntity.uuCreateSet(from: models, in: context)
            XCTAssertEqual(created.count, 3)
            XCTAssertEqual(Set(created.map(\.identifier)), Set([id1, id2, id3]))

            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            let rows = try? context.fetch(req)
            XCTAssertEqual(rows?.count, 3)
        }
    }

    func test_uuCreateSet_empty_returnsEmptySet()
    {
        performOnPlayerStack(storeLabel: "uuCreateSet_empty")
        { context in
            let created = PlayerEntity.uuCreateSet(from: [], in: context)
            XCTAssertTrue(created.isEmpty)
            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            let rows = try? context.fetch(req)
            XCTAssertEqual(rows?.count, 0)
        }
    }

    func test_uuCreateSet_withAppContext()
    {
        performOnPlayerStack(storeLabel: "uuCreateSet_appCtx")
        { context in
            let models = [
                Player(identifier: UUID(), name: "SetCtx", number: 0, gamesPlayed: 0, nickName: nil),
            ]
            var appContext: Any? = 99
            let out = PlayerEntity.uuCreateSet(from: models, in: context, with: &appContext)
            XCTAssertEqual(out.count, 1)
            XCTAssertEqual(appContext as? Int, 99)
            XCTAssertNil(context.uuSave())
        }
    }

    func test_asModels_mapsFetchedEntitiesToPlayer()
    {
        performOnPlayerStack(storeLabel: "asModels_roundTrip")
        { context in
            let p1 = Player(identifier: UUID(), name: "M1", number: 5, gamesPlayed: 5, nickName: "m")
            let p2 = Player(identifier: UUID(), name: "M2", number: 6, gamesPlayed: 6, nickName: nil)
            _ = PlayerEntity.uuCreateArray(from: [p1, p2], in: context)
            XCTAssertNil(context.uuSave())

            let req = PlayerEntity.fetchRequest()
            let rows = (try? context.fetch(req)) ?? []
            let models = rows.asModels
            XCTAssertEqual(models.count, 2)
            XCTAssertTrue(models.contains { $0.identifier == p1.identifier && $0.name == "M1" && $0.nickName == "m" })
            XCTAssertTrue(models.contains { $0.identifier == p2.identifier && $0.name == "M2" && $0.nickName == nil })
        }
    }
}


@objc
class PlayerEntity: NSManagedObject, Identifiable
{
    @NSManaged public var identifier: UUID
    @NSManaged public var name: String
    @NSManaged public var number: Int16
    @NSManaged public var gamesPlayed: Int32
    @NSManaged public var nickName: String?
}

struct Player: Codable
{
    var identifier: UUID
    var name: String
    var number: Int16
    var gamesPlayed: Int32
    var nickName: String?
}

extension PlayerEntity: UUEntityModelConvertible
{
    typealias Model = Player
        
    var asModel: Player
    {
        return Player(
            identifier: self.identifier,
            name: self.name,
            number: self.number,
            gamesPlayed: self.gamesPlayed,
            nickName: self.nickName)
    }
    
    func populate(from: Model, context: NSManagedObjectContext, appContext: inout Any?)
    {
        self.identifier = from.identifier
        self.name = from.name
        self.number = from.number
        self.gamesPlayed = from.gamesPlayed
        self.nickName = from.nickName
    }
}

extension PlayerEntity
{
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerEntity>
    {
        return NSFetchRequest<PlayerEntity>(entityName: "PlayerEntity")
    }
    
    static func entityDescription() -> NSEntityDescription
    {
        let e = NSEntityDescription()
        e.name = uuClassName
        e.managedObjectClassName = NSStringFromClass(PlayerEntity.self)
        
        let identifierAttribute = NSAttributeDescription()
        identifierAttribute.name = "identifier"
        identifierAttribute.attributeType = .UUIDAttributeType
        identifierAttribute.isOptional = false
        e.properties.append(identifierAttribute)
        
        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = false
        e.properties.append(nameAttribute)
        
        let numberAttribute = NSAttributeDescription()
        numberAttribute.name = "number"
        numberAttribute.attributeType = .integer16AttributeType
        numberAttribute.defaultValue = 0
        e.properties.append(numberAttribute)
        
        let gamesPlayedAttribute = NSAttributeDescription()
        gamesPlayedAttribute.name = "gamesPlayed"
        gamesPlayedAttribute.attributeType = .integer32AttributeType
        gamesPlayedAttribute.defaultValue = 0
        e.properties.append(gamesPlayedAttribute)
        
        let nickNameAttribute = NSAttributeDescription()
        nickNameAttribute.name = "nickName"
        nickNameAttribute.attributeType = .stringAttributeType
        nickNameAttribute.isOptional = true
        e.properties.append(nickNameAttribute)
        
        return e
    }
}
