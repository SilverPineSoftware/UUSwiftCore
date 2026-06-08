//
//  UUPrintLogWriter.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/21/24.
//

import Foundation

/// A logger class that logs messages to the console using swift print.
/// Conforms to the `UULogWriter` protocol.
public class UUPrintLogWriter: UULogWriter
{
    /// Writes a log entry with the specified log level, tag, and formatted message.
    ///
    /// - Parameters:
    ///   - level: The severity level of the log message, represented by the `UULogLevel` enum.
    ///            Common levels include `.verbose`, `.debug`, `.info`, `.warn`, `.error`, and `.fatal`.
    ///
    ///   - tag: A `String` identifier that categorizes the log message, such as a component or module name.
    ///          Useful for filtering logs based on context.
    ///
    ///   - message: A `String` log message.
    public func writeToLog(level: UULogLevel, tag: String, message: String)
    {
        print(formatLogLine(level: level, tag: tag, message: message))
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
