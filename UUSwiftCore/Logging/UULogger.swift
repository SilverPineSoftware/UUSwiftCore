//
//  UULogger.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/20/24.
//  Copyright © 2024 Silverpine Software. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//

import Foundation

/// A protocol defining a logging mechanism for structured log output.
/// Types conforming to `UULogger` must implement a method to log messages with
/// varying levels of severity, a descriptive tag, and a formatted message.
public protocol UULogger
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
    var logLevel: UULogLevel { get set }
    
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
    func writeToLog(level: UULogLevel, tag: String, message: String)
}
