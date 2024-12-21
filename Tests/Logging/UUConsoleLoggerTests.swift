//
//  UUConsoleLoggerTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/20/24.
//

import XCTest
@testable import UUSwiftCore

/// A mock class to capture log messages instead of printing to the console.
fileprivate class MockConsoleLogger: UUConsoleLogger
{
    var capturedLogLine: String?

    override func writeToLog(level: UULogLevel, tag: String, message: String)
    {
        capturedLogLine = formatLogLine(level: level, tag: tag, message: message)
        super.writeToLog(level: level, tag: tag, message: message)
    }
}

final class UUConsoleLoggerTests: XCTestCase
{
    private let logger = MockConsoleLogger()
    
    func testConsoleLogger() throws
    {
        logger.writeToLog(level: .debug, tag: "UnitTest", message: "Hello World")
        XCTAssertNotNil(logger.capturedLogLine)
        XCTAssertTrue(logger.capturedLogLine?.contains("DEBUG") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("UnitTest") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("Hello World") == true)
        
        logger.writeToLog(level: .info, tag: "MyClass", message: "I Live In a Van Down by the River")
        XCTAssertNotNil(logger.capturedLogLine)
        XCTAssertTrue(logger.capturedLogLine?.contains("INFO") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("MyClass") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("I Live In a Van Down by the River") == true)
        
        logger.writeToLog(level: .warn, tag: "SomeService", message: "Whatever's Clever")
        XCTAssertNotNil(logger.capturedLogLine)
        XCTAssertTrue(logger.capturedLogLine?.contains("WARN") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("SomeService") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("Whatever's Clever") == true)
        
        logger.writeToLog(level: .error, tag: "Whatever", message: "Red Rover Red Rover, Send Unit Tests right over!")
        XCTAssertNotNil(logger.capturedLogLine)
        XCTAssertTrue(logger.capturedLogLine?.contains("ERROR") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("Whatever") == true)
        XCTAssertTrue(logger.capturedLogLine?.contains("Red Rover Red Rover, Send Unit Tests right over!") == true)
    }

}
