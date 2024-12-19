//
//  UUTimeMeasurementTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 11/30/24.
//

import XCTest
import UUSwiftTestCore

@testable import UUSwiftCore

final class UUTimeMeasurementTests: XCTestCase
{
    func testSimple() throws
    {
        let measurement = UUTimeMeasurement(name: "Test Measurement")
        
        measurement.start()
        
        let sleepTime: TimeInterval = 1.0
        Thread.sleep(forTimeInterval: sleepTime)
        
        measurement.end()
        
        let duration = measurement.duration
        
        XCTAssertTrue(duration >= sleepTime)
        
        UUDebugLog("\(measurement)")
    }
}
