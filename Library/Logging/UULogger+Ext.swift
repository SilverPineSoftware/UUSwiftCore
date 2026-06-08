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

/// A static property that provides a default logger instance configured to write logs to the console.
///
/// This convenience property returns a `UULogger` instance that uses a `UUConsoleLogWriter` for logging.
/// It is ideal for quick setup when you want to log messages directly to the console.
///
/// ### Example
/// ```swift
/// // Use the default console logger.
/// let logger = UULogger.console
///
/// // Log messages will be output to the console.
/// logger.writeToLog(level: .info, tag: "ConsoleLogger", message: "This message will appear in the console.")
/// ```
///
/// - Note: This property simplifies the creation of a console-based logger, making it suitable for debugging
///   or applications that do not require custom log destinations.
public extension UULogger
{
    static var console: UULogger
    {
        return UULogger(UUConsoleLogWriter())
    }
    
    static var print: UULogger
    {
        return UULogger(UUPrintLogWriter())
    }
}
