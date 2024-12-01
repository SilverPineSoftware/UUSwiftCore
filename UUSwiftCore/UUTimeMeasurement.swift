//
//  UUTimeMeasurement.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 11/30/24.
//

import UIKit

// Container for recording simple timed measurements
open class UUTimeMeasurement
{
    public var name: String? = nil
    public var startTime: TimeInterval? = nil
    public var endTime: TimeInterval? = nil
    
    required public init(name: String? = nil)
    {
        self.name = name
    }
    
    public func start()
    {
        startTime = Date.timeIntervalSinceReferenceDate
        endTime = nil
    }
    
    public func end()
    {
        endTime = Date.timeIntervalSinceReferenceDate
        
        if (startTime == nil)
        {
            startTime = endTime
        }
    }
    
    public var duration: TimeInterval
    {
        guard let startTime, let endTime else { return 0 }
        
        return endTime - startTime
    }
}

extension UUTimeMeasurement: CustomStringConvertible
{
    public var description: String
    {
        return "\(name ?? ""): \(duration)"
    }
}
