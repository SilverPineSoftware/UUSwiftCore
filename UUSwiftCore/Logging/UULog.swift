//
//  UULog.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/20/24.
//  Copyright © 2024 Silverpine Software. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//

import Foundation

/// A utility class for logging messages at various levels of severity.
/// Provides convenience methods for logging verbose, debug, info, warning, error, and fatal messages.
///
/// ### Usage Example
/// ```swift
/// // Create a console logger instance.
/// let consoleLogger = UULogger.console
///
/// // Initialize UULog with the console logger.
/// let log = UULog.init(consoleLogger)
///
/// // Log messages at different severity levels.
/// log.verbose(tag: "Startup", message: "Application is starting up.")
/// log.debug(tag: "Networking", message: "Fetching data from API endpoint.")
/// log.info(tag: "Database", message: "User data loaded successfully.")
/// log.warn(tag: "Memory", message: "Memory usage is nearing the limit.")
/// log.error(tag: "FileIO", message: "Failed to save file to disk.")
/// log.fatal(tag: "Crash", message: "Unrecoverable error occurred. Shutting down.")
/// ```
///
/// ### Key Notes
/// - You can customize the logger by providing your own implementation of `UULogger`.
/// - If no logger is provided during initialization, the `UULog` instance will silently ignore logging calls.

public struct UULog
{
    /// The logger instance used to handle log messages.
    private static var logger: UULogger? = nil

    /// Initializes the current logger `UULog` with an optional logger.
    ///
    /// - Parameter logger: An instance conforming to the `UULogger` protocol. If `nil`, no logs will be written.
    public static func setLogger(_ logger: UULogger?)
    {
        UULog.logger = logger
    }
    
    /// Logs a verbose message.
    ///
    /// - Parameters:
    ///   - tag: A short identifier for the source of the log message.
    ///   - message: The message to be logged.
    public static func verbose(tag: String, message: String)
    {
        logger?.writeToLog(level: .verbose, tag: tag, message: message)
    }
    
    /// Logs a debug message.
    ///
    /// - Parameters:
    ///   - tag: A short identifier for the source of the log message.
    ///   - message: The message to be logged.
    public static func debug(tag: String, message: String)
    {
        logger?.writeToLog(level: .debug, tag: tag, message: message)
    }
    
    /// Logs an informational message.
    ///
    /// - Parameters:
    ///   - tag: A short identifier for the source of the log message.
    ///   - message: The message to be logged.
    public static func info(tag: String, message: String)
    {
        logger?.writeToLog(level: .info, tag: tag, message: message)
    }
    
    /// Logs a warning message.
    ///
    /// - Parameters:
    ///   - tag: A short identifier for the source of the log message.
    ///   - message: The message to be logged.
    public static func warn(tag: String, message: String)
    {
        logger?.writeToLog(level: .warn, tag: tag, message: message)
    }
    
    /// Logs an error message.
    ///
    /// - Parameters:
    ///   - tag: A short identifier for the source of the log message.
    ///   - message: The message to be logged.
    public static func error(tag: String, message: String)
    {
        logger?.writeToLog(level: .error, tag: tag, message: message)
    }
    
    /// Logs a fatal message. Use this method for critical errors that may cause the application to crash.
    ///
    /// - Parameters:
    ///   - tag: A short identifier for the source of the log message.
    ///   - message: The message to be logged.
    public static func fatal(tag: String, message: String)
    {
        logger?.writeToLog(level: .fatal, tag: tag, message: message)
    }
}
