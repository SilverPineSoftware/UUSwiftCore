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
    /// Writes a log message to the console with a specified log level, tag, and message.
    ///
    /// - Parameters:
    ///   - level: The severity level of the log message (e.g., debug, info, error).
    ///   - tag: A short tag or identifier for the source of the log message.
    ///   - message: The message to be logged.
    public func writeToLog(level: UULogLevel, tag: String, message: String)
    {
        NSLog(formatLogLine(level: level, tag: tag, message: message))
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
