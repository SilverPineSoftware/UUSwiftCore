//
//  UUTimer.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 8/17/21.
//

import Foundation

public typealias UUTimerBlock = ((UUTimer)->())
public typealias UUWatchdogTimerBlock = ((Any?)->())

/*
 UUTimer wraps GCD timers. GCD Timers continue to execute even when the application is backgrounded, making
 UUTimer ideal for things that might run in the background.  The main inspiration for this class was a need
 to have a simple block based 'watchdog' type of timer that could be canceled.
 */
public class UUTimer
{
    public let timerId: String
    public let userInfo: Any?
    public let interval: TimeInterval
    private(set) public var lastFireTime: TimeInterval = 0
    private let pool: UUTimerPool
    
    public let shouldRepeat: Bool
    private var dispatchSource: DispatchSourceTimer? = nil
    
    public required init(
        timerId: String = UUID().uuidString,
        interval: TimeInterval,
        userInfo: Any? = nil,
        shouldRepeat: Bool = false,
        queue: DispatchQueue,
        pool: UUTimerPool = UUTimerPool.shared,
        block: @escaping UUTimerBlock)
    {
        self.timerId = timerId
        self.interval = interval
        self.userInfo = userInfo
        self.shouldRepeat = shouldRepeat
        self.lastFireTime = 0
        self.pool = pool
        
        self.dispatchSource = DispatchSource.makeTimerSource(flags: [], queue: queue)
        
        self.lastFireTime = Date().timeIntervalSinceReferenceDate
        
        var repeatingInterval: DispatchTimeInterval = .never
        if (shouldRepeat)
        {
            repeatingInterval = .milliseconds(Int(interval * 1000.0))
        }
        
        let fireTime: DispatchTime = (.now() + interval)
        
        self.dispatchSource?.schedule(deadline: fireTime, repeating: repeatingInterval, leeway: .never)
        self.dispatchSource?.setEventHandler
        {
            block(self)
            
            if (!shouldRepeat)
            {
                self.cancel()
            }
        }
    }
    
    // Returns a shared serial queue for executing timers on a background thread
    public static func backgroundThreadTimerQueue() -> DispatchQueue
    {
        return DispatchQueue.global(qos: .userInteractive)
    }
    
    // Alias for DispatchQueue.main
    public static func mainThreadTimerQueue() -> DispatchQueue
    {
        return DispatchQueue.main
    }
    
    public func start()
    {
        if let src = dispatchSource
        {
            //NSLog("Starting timer \(timerId), interval: \(interval), repeat: \(shouldRepeat), dispatchSource: \(String(describing: dispatchSource)), userInfo: \(String(describing: userInfo))")
            pool.addTimer(self)
            src.resume()
        }
        else
        {
            //NSLog("Cannot start timer \(timerId) because dispatch source is nil")
        }
    }
    
    public func cancel()
    {
        //NSLog("Cancelling timer \(timerId), dispatchSource: \(String(describing: dispatchSource)), userInfo: \(String(describing: userInfo))")
        
        if let src = dispatchSource
        {
            src.cancel()
            
            self.dispatchSource = nil
        }
        
        pool.removeTimer(self)
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
    
    public static let shared = UUTimerPool()
    
    public func addTimer(_ timer: UUTimer)
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        activeTimers[timer.timerId] = timer
    }
    
    public func removeTimer(_ timer: UUTimer)
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        activeTimers.removeValue(forKey: timer.timerId)
    }
    
    // Find an active timer by its ID
    public func findActiveTimer(_ timerId: String) -> UUTimer?
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        return activeTimers[timerId]
    }
    
    // Lists all active timers
    public func listActiveTimers() -> [UUTimer]
    {
        defer { activeTimersLock.unlock() }
        activeTimersLock.lock()
        
        return activeTimers.values.compactMap({ $0 })
    }
}

public extension UUTimerPool // Watchdog Timer support
{
    func startWatchdogTimer(
        timerId: String,
        timeout: TimeInterval,
        userInfo: Any?,
        queue: DispatchQueue = UUTimer.backgroundThreadTimerQueue(),
        block: UUWatchdogTimerBlock?)
    {
        cancelWatchdogTimer(timerId: timerId)
        
        if (timeout > 0)
        {
            let t = UUTimer(timerId: timerId, interval: timeout, userInfo: userInfo, shouldRepeat: false, queue: queue)
            { _ in
                if let b = block
                {
                    b(userInfo)
                }
            }
            
            t.start()
        }
    }
    
    func cancelWatchdogTimer(timerId: String)
    {
        if let t = UUTimerPool.shared.findActiveTimer(timerId)
        {
            t.cancel()
        }
    }
}
