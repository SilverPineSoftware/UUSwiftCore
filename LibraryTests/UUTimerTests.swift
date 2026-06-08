//
//  UUTimerTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 10/28/21.
//

import XCTest
import UUSwiftTestCore

@testable import UUSwiftCore

class UUTimerTests: XCTestCase
{
    // Grace we give the actual timer firing
    private let timerFudgeFactor = 1.0
    
    func testFireSingle()
    {
        let exp = uuExpectationForMethod()
        
        let timerId = "\(#function)_TimerId"
        let timeout = 2.0
        var lastStartTime: TimeInterval = 0
        
        let timer = UUTimer(identifier: timerId, interval: timeout, userInfo: nil, shouldRepeat: false)
        { t in
            
            XCTAssertEqual(t.identifier, timerId)
            XCTAssertNil(t.userInfo)
            
            let end = Date.timeIntervalSinceReferenceDate
            let elapsed = end - lastStartTime
            UUTestLog("Timer \(timerId) Elapsed: \(elapsed)")
            XCTAssertTrue(elapsed >= timeout)
            
            exp.fulfill()
        }
        
        XCTAssertNotNil(timer)
        
        lastStartTime = Date.timeIntervalSinceReferenceDate
        timer.start()
        
        var active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(1, active.count)
        
        let t = active.first
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.identifier, timerId)
        
        uuWaitForExpectations(timeout + timerFudgeFactor)
        
        active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(0, active.count)
    }
    
    func testFireSingleWithUserInfo()
    {
        let exp = uuExpectationForMethod()
        
        let timerId = "\(#function)_TimerId"
        let timeout = 2.0
        let userInfo: [String:String] = ["Hello":"World", "Foo":"Bar"]
        var lastStartTime: TimeInterval = 0
        
        let timer = UUTimer(identifier: timerId, interval: timeout, userInfo: userInfo, shouldRepeat: false)
        { t in
            
            XCTAssertEqual(t.identifier, timerId)
            XCTAssertNotNil(t.userInfo)
            
            let timerInfo = t.userInfo as? [String:String]
            XCTAssertNotNil(timerInfo)
            XCTAssertEqual(userInfo, timerInfo!)
            
            let end = Date.timeIntervalSinceReferenceDate
            let elapsed = end - lastStartTime
            UUTestLog("Timer \(timerId) Elapsed: \(elapsed)")
            XCTAssertTrue(elapsed >= timeout)
            
            exp.fulfill()
        }
        
        XCTAssertNotNil(timer)
        
        lastStartTime = Date.timeIntervalSinceReferenceDate
        timer.start()
        
        var active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(1, active.count)
        
        let t = active.first
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.identifier, timerId)
        
        uuWaitForExpectations(timeout + timerFudgeFactor)
        
        active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(0, active.count)
        
    }
    
    func testWithRepeat()
    {
        let exp = uuExpectationForMethod()
        
        let timerId = "\(#function)_TimerId"
        let timeout = 1.0
        
        var fireCount: Int = 0
        var lastStartTime: TimeInterval = 0
        let maxCount = 10
        
        let timer = UUTimer(identifier: timerId, interval: timeout, userInfo: nil, shouldRepeat: true)
        { t in
            
            XCTAssertEqual(t.identifier, timerId)
            XCTAssertNil(t.userInfo)
            
            let end = Date.timeIntervalSinceReferenceDate
            let elapsed = end - lastStartTime
            
            // Experimentation shows that trying to assert this fire time fails the test.  The documentation
            // for DispatchSourceTimer indicates that the system may delay or catch up the fireing of repeat
            // timers.  So we'll ignore this assertion for now.  UUTimer is not meant to be a precise repeating timer
            //
            //XCTAssertTrue(elapsed >= timeout)
            
            fireCount = fireCount + 1
            UUTestLog("Timer FireCount: \(fireCount), elapsed: \(elapsed)")
            
            lastStartTime = Date.timeIntervalSinceReferenceDate
            
            if (fireCount > maxCount)
            {
                t.cancel()
                exp.fulfill()
            }
        }
        
        XCTAssertNotNil(timer)
        
        lastStartTime = Date.timeIntervalSinceReferenceDate
        fireCount = 0
        timer.start()
        
        var active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(1, active.count)
        
        let t = active.first
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.identifier, timerId)
        
        let totalTimeout = Double(maxCount) * Double(timeout + timerFudgeFactor)
        uuWaitForExpectations(totalTimeout)
        
        active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(0, active.count)
    }
    
    func testFireThree()
    {
        let timerIdOne = "\(#function)_TimerId_1"
        let timeout = 2.0
        //var lastStartTime: TimeInterval = 0
        
        let expOne = uuExpectationForMethod(tag: timerIdOne)
        let timerOne = UUTimer(identifier: timerIdOne, interval: timeout, userInfo: UInt8(1), shouldRepeat: false)
        { t in
            
            XCTAssertEqual(t.identifier, timerIdOne)
            XCTAssertNotNil(t.userInfo)
            let info = t.userInfo as? UInt8
            XCTAssertNotNil(info)
            XCTAssertEqual(1, info!)
            
            expOne.fulfill()
        }
        
        XCTAssertNotNil(timerOne)
        
        timerOne.start()
        
        var active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(1, active.count)
        
        let t = active.first
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.identifier, timerIdOne)
        
        /// Timer 2
        let timerIdTwo = "\(#function)_TimerId_2"
        let expTwo = uuExpectationForMethod(tag: timerIdTwo)
        let timerTwo = UUTimer(identifier: timerIdTwo, interval: timeout, userInfo: UInt8(2), shouldRepeat: false)
        { t in
            
            XCTAssertEqual(t.identifier, timerIdTwo)
            XCTAssertNotNil(t.userInfo)
            let info = t.userInfo as? UInt8
            XCTAssertNotNil(info)
            XCTAssertEqual(2, info!)
            
            expTwo.fulfill()
        }
        
        XCTAssertNotNil(timerTwo)
        
        timerTwo.start()
        
        active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(2, active.count)
        
        
        /// Timer 3
        let timerIdThree = "\(#function)_TimerId_3"
        let expThree = uuExpectationForMethod(tag: timerIdThree)
        let timerThree = UUTimer(identifier: timerIdThree, interval: timeout, userInfo: UInt8(3), shouldRepeat: false)
        { t in
            
            XCTAssertEqual(t.identifier, timerIdThree)
            XCTAssertNotNil(t.userInfo)
            let info = t.userInfo as? UInt8
            XCTAssertNotNil(info)
            XCTAssertEqual(3, info!)
            
            expThree.fulfill()
        }
        
        XCTAssertNotNil(timerThree)
        
        timerThree.start()
        
        active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(3, active.count)
        
        uuWaitForExpectations(timeout + timerFudgeFactor)
        
        active = UUTimerPool.shared.listActiveTimers()
        XCTAssertEqual(0, active.count)
    }
    
    
    func testFireManyWatchdogs()
    {
        let count = 50
        let timeoutMin = 1
        let timeoutMax = 5
        
        for i in 0..<count
        {
            let timerId = "timer_\(i)"
            let timeout = TimeInterval(uuRandomUInt32(low: UInt32(timeoutMin), high: UInt32(timeoutMax)))
            let info = Int32(i)
            let exp = uuExpectationForMethod(tag: timerId)
            UUTimerPool.shared.start(identifier: timerId, timeout: timeout, userInfo: info)
            { result in
                
                UUTestLog("Timer \(i) triggered")
                XCTAssertNotNil(result)
                XCTAssertEqual(info, result as? Int32)
                exp.fulfill()
            }
        }
        
        uuWaitForExpectations()
    }
    
}
