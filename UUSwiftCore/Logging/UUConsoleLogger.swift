//
//  UUConsoleLogger.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/20/24.
//  Copyright © 2024 Silverpine Software. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//

import Foundation

/// A logger class that logs messages to the console using NSLog.
/// Conforms to the `UULogger` protocol.
public class UUConsoleLogger: UULogger
{
    /// The log level threshold for the logger.
    ///
    /// Only messages at or above this level will be logged. Messages with a lower severity will be ignored.
    ///
    /// ### Usage
    /// - Set this property to control the verbosity of the logger.
    /// - For example, if `logLevel` is set to `.info`, only `.info`, `.warn`, `.error`, and `.fatal` messages will be logged.
    ///   Messages with `.verbose` or `.debug` levels will be ignored.
    ///
    /// ### Example
    /// ```swift
    /// var logger: UULogger = SomeLoggerImplementation()
    /// logger.logLevel = .warn
    ///
    /// logger.writeToLog(level: .info, tag: "Example", message: "This will not be logged.")
    /// logger.writeToLog(level: .warn, tag: "Example", message: "This will be logged.")
    /// ```
    ///
    /// - Note: This property allows developers to dynamically control the verbosity of logs during runtime.
    /// - Note: Default is `.debug`
    public var logLevel: UULogLevel = .debug
    
    /// Writes a log message to the console with a specified log level, tag, and message.
    ///
    /// - Parameters:
    ///   - level: The severity level of the log message (e.g., debug, info, error).
    ///   - tag: A short tag or identifier for the source of the log message.
    ///   - message: The message to be logged.
    public func writeToLog(level: UULogLevel, tag: String, message: String)
    {
        guard shouldLog(level: level) else
        {
            return
        }
        
        NSLog(formatLogLine(level: level, tag: tag, message: message))
    }
    
    /// Checks whether or not an incoming leg level is at or above the current log level configured for this logger.
    ///
    func shouldLog(level: UULogLevel) -> Bool
    {
        return level.rawValue >= self.logLevel.rawValue
    }
    
    /// Formats a log message.  Output is of the form:
    ///
    /// [DateTime] [LogLevel] [Tag] [Message]
    ///
    /// - Example:
    ///
    /// 2024-12-20T19:00:48.466-0800 DEBUG UnitTest Hello World
    ///
    /// - Parameters:
    ///   - level: The severity level of the log message (e.g., debug, info, error).
    ///   - tag: A short tag or identifier for the source of the log message.
    ///   - message: The message to be logged.
    func formatLogLine(level: UULogLevel, tag: String, message: String) -> String
    {
        let timestamp = Date().uuFormat(UUDate.Formats.rfc3339WithMillisTimeZone, timeZone: .current)
        return "\(timestamp) \(level) \(tag) \(message)"
    }
}
