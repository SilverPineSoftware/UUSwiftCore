//
//  UULogLevel.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/20/24.
//  Copyright © 2024 Silverpine Software. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//

import Foundation

/// Represents different levels of logging severity.
///
/// `UULogLevel` is an enumeration that defines various levels of logging, ranging from
/// detailed debugging information to critical errors. Each log level is associated
/// with an integer value to facilitate comparisons and filtering of log messages.
public enum UULogLevel: Int, CaseIterable, CustomStringConvertible
{
    /// Provides a string description for each logging level, simply returns an upper cased version of the enum name
    public var description: String
    {
        switch (self)
        {
            case .verbose:
                return "VERBOSE"
            
            case .debug:
                return "DEBUG"
            
            case .info:
                return "INFO"
            
            case .warn:
                return "WARN"
            
            case .error:
                return "ERROR"
            
            case .fatal:
                return "FATAL"
        }
    }
    
    /// Verbose logging level (2).
    /// Provides the most detailed and fine-grained information.
    /// Typically used for detailed tracing and debugging purposes.
    case verbose = 2

    /// Debug logging level (3).
    /// Used to provide diagnostic information useful during development.
    /// Less detailed than verbose but still useful for debugging.
    case debug = 3

    /// Info logging level (4).
    /// Used to report general operational messages and key events.
    /// Indicates that things are working as expected.
    case info = 4

    /// Warning logging level (5).
    /// Indicates potential issues or unexpected situations that do not prevent
    /// the application from functioning but may need attention.
    case warn = 5

    /// Error logging level (6).
    /// Indicates a significant problem that occurred, but the application can still continue running.
    case error = 6

    /// Fatal logging level (7).
    /// Represents critical issues that lead to the immediate termination of the application.
    /// Indicates a severe problem that must be addressed immediately.
    case fatal = 7
}
