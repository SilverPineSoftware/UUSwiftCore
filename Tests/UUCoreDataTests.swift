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
