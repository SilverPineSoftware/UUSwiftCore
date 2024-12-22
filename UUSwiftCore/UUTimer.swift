//
//  UUTimer.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 8/17/21.
//

import Foundation

fileprivate let LOG_TAG : String = "UUTimer"

public typealias UUTimerBlock = ((UUTimer)->())
public typealias UUWatchdogTimerBlock = ((Any?)->())

/*
 UUTimer wraps GCD timers. GCD Timers continue to execute even when the application is backgrounded, making
 UUTimer ideal for things that might run in the background.  The main inspiration for this class was a need
 to have a simple block based 'watchdog' type of timer that could be canceled.
 */
public class UUTimer
{
    public let identifier: String
    public let userInfo: Any?
    public let interval: TimeInterval
    private(set) public var lastFireTime: TimeInterval = 0
    private let pool: UUTimerPool
    
    public let shouldRepeat: Bool
    private var dispatchSource: DispatchSourceTimer? = nil
    
    public required init(
        identifier: String = UUID().uuidString,
        interval: TimeInterval,
        userInfo: Any? = nil,
        shouldRepeat: Bool = false,
        pool: UUTimerPool = UUTimerPool.shared,
        block: @escaping UUTimerBlock)
    {
        self.identifier = identifier
        self.interval = interval
        self.userInfo = userInfo
        self.shouldRepeat = shouldRepeat
        self.lastFireTime = 0
        self.pool = pool
        
        self.dispatchSource = DispatchSource.makeTimerSource(flags: [], queue: pool.dispatchQueue)
        
        self.lastFireTime = Date().timeIntervalSinceReferenceDate
        
        var repeatingInterval: DispatchTimeInterval = .never
        if (shouldRepeat)
        {
            repeatingInterval = .milliseconds(Int(interval * 1000.0))
        }
        
        let fireTime: DispatchTime = (.now() + interval)
        
        self.dispatchSource?.setEventHandler
        {
            block(self)
            
            if (!shouldRepeat)
            {
                self.cancel()
            }
        }
        
        self.dispatchSource?.schedule(deadline: fireTime, repeating: repeatingInterval)
    }
    
    public func start()
    {
        if let src = dispatchSource
        {
            UULog.verbose(tag: LOG_TAG, message: "Starting timer \(identifier), interval: \(interval), repeat: \(shouldRepeat), dispatchSource: \(String(describing: dispatchSource)), userInfo: \(String(describing: userInfo))")
            pool.add(self)
            src.resume()
        }
        else
        {
            UULog.verbose(tag: LOG_TAG, message: "Cannot start timer \(identifier) because dispatch source is nil")
        }
    }
    
    public func cancel()
    {
        UULog.verbose(tag: LOG_TAG, message: "Cancelling timer \(identifier), dispatchSource: \(String(describing: dispatchSource)), userInfo: \(String(describing: userInfo))")
        
        if let src = dispatchSource
        {
            src.cancel()
            
            self.dispatchSource = nil
        }
        
        pool.remove(self)
    }
}

/**
 UUTimerPool keeps track of a number of timers.  Because the timers are often used in a one off way, having an object keep a reference
 to them ensures they aren't cleaned up prior to firing and performing their duty.  The pool also offers a way to lookup timers by ID and
 find all active timers in the pool.
 */
public class UUTimerPool
{
    private var activeTimers: [String:UUTimer] = [:]
    private let activeTimersLock = NSRecursiveLock()
    
    private static var pools: [String:UUTimerPool] = [:]
    private static let poolsLock = NSRecursiveLock()
    
    public static let shared = UUTimerPool.getPool("UUTimerPool.shared", queue: DispatchQueue.main)
    
    public let identifier: String
    public let dispatchQueue: DispatchQueue
    
    public static func getPool(_ identifier: String, queue: DispatchQueue = DispatchQueue.global(qos: .userInteractive)) -> UUTimerPool
    {
        defer { poolsLock.unlock() }
        poolsLock.lock()
        
        var pool = pools[identifier]
        if (pool == nil)
        {
            pool = UUTimerPool(identifier: identifier, queue: queue)
            pools[identifier] = pool
        }
        
        return pool!
    }
    
    internal required init(identifier: String, queue: DispatchQueue)
    {
        self.identifier = identifier
        self.dispatchQueue = queue
    }
    
    public func add(_ timer: UUTimer)
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        activeTimers[timer.identifier] = timer
    }
    
    public func remove(_ timer: UUTimer)
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        activeTimers.removeValue(forKey: timer.identifier)
    }
    
    // Find an active timer by its ID
    public func find(by identifier: String) -> UUTimer?
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        return activeTimers[identifier]
    }
    
    // Lists all active timers
    public func listActiveTimers() -> [UUTimer]
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        return activeTimers.values.compactMap({ $0 })
    }
    
    public func cancel(by identifier: String)
    {
        find(by: identifier)?.cancel()
    }
    
    public func cancelAllTimers()
    {
        UULog.verbose(tag: LOG_TAG, message: "Cancelling all timers")
        
        let list = listActiveTimers()
        UULog.verbose(tag: LOG_TAG, message: "There are \(list.count) active timers")
        
        list.forEach
        { t in
            UULog.verbose(tag: LOG_TAG, message: "Canceling timer \(t.identifier)")
            t.cancel()
        }
    }
}

public extension UUTimerPool // Watchdog Timer support
{
    func start(
        identifier: String,
        timeout: TimeInterval,
        userInfo: Any?,
        block: UUWatchdogTimerBlock?)
    {
        cancel(by: identifier)
        
        if (timeout > 0)
        {
            let t = UUTimer(identifier: identifier, interval: timeout, userInfo: userInfo, shouldRepeat: false, pool: self)
            { _ in
                if let b = block
                {
                    b(userInfo)
                }
            }
            
            t.start()
        }
    }
}
