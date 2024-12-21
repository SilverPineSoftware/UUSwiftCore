//
//  UUConsoleLoggerTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/20/24.
//

import XCTest
@testable import UUSwiftCore

fileprivate class MockLogWriter: UUConsoleLogWriter
{
    var capturedLogLine: String?

    override func writeToLog(level: UULogLevel, tag: String, message: String)
    {
        capturedLogLine = formatLogLine(level: level, tag: tag, message: message)
        super.writeToLog(level: level, tag: tag, message: message)
    }
}

fileprivate class MockLogger: UULogger
{
    var mockWriter = MockLogWriter()
    
    init()
    {
        super.init(mockWriter)
    }
    
    var capturedLogLine: String?
    {
        return mockWriter.capturedLogLine
    }
}

fileprivate struct TestInput
{
    var level: UULogLevel
    var tag: String
    var message: String
    var expectLogged: Bool = true
    
    init(level: UULogLevel, tag: String, message: String, expectLogged: Bool)
    {
        self.level = level
        self.tag = tag
        self.message = message
        self.expectLogged = expectLogged
    }
    
    func assertLogged(_ logger: MockLogger)
    {
        XCTAssertNotNil(logger.capturedLogLine)
        XCTAssertTrue(logger.capturedLogLine?.contains(level.description) == true)
        XCTAssertTrue(logger.capturedLogLine?.contains(tag) == true)
        XCTAssertTrue(logger.capturedLogLine?.contains(message) == true)
    }
    
    func assertNotLogged(_ logger: MockLogger)
    {
        XCTAssertNil(logger.capturedLogLine)
    }
    
    func doTest(_ logger: MockLogger)
    {
        logger.writeToLog(level: level, tag: tag, message: message)
        
        if expectLogged
        {
            assertLogged(logger)
        }
        else
        {
            assertNotLogged(logger)
        }
    }
}

final class UUConsoleLoggerTests: XCTestCase
{
    private let logger = MockLogger()
    
    func testConsoleLogger_verbose() throws
    {
        logger.logLevel = .verbose
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: true),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: true),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: true),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: true),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
    
    func testConsoleLogger_debug() throws
    {
        logger.logLevel = .debug
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: false),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: true),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: true),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: true),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
    
    func testConsoleLogger_info() throws
    {
        logger.logLevel = .info
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: false),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: false),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: true),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: true),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
    
    func testConsoleLogger_warn() throws
    {
        logger.logLevel = .warn
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: false),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: false),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: false),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: true),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: true),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
    
    func testConsoleLogger_error() throws
    {
        logger.logLevel = .error
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: false),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: false),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: false),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: false),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: true),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: true),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
    
    func testConsoleLogger_fatal() throws
    {
        logger.logLevel = .fatal
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: false),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: false),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: false),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: false),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: false),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: true),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
    
    func testConsoleLogger_off() throws
    {
        logger.logLevel = .off
        
        let td =
        [
            TestInput(level: .verbose, tag: "UnitTest", message: "Init Here", expectLogged: false),
            TestInput(level: .debug, tag: "UnitTest", message: "Hello World", expectLogged: false),
            TestInput(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: false),
            TestInput(level: .warn, tag: "SomeService", message: "Whatever's Clever", expectLogged: false),
            TestInput(level: .error, tag: "MyClass", message: "I Live In a Van Down by the River", expectLogged: false),
            TestInput(level: .fatal, tag: "YoYo", message: "I like lamp", expectLogged: false),
        ]
        
        for input in td
        {
            input.doTest(logger)
        }
    }
}
