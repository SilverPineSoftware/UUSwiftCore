//
//  UULogWriter.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 12/21/24.
//  Copyright © 2024 Silverpine Software. All rights reserved.
//
//  This file is part of UUSwiftCore, distributed under the MIT License.
//  See LICENSE file for details.
//

import Foundation

/// A protocol defining a logging mechanism for structured log output.
/// Types conforming to `UULogWriter` must implement a method to log messages with
/// varying levels of severity, a descriptive tag, and a formatted message.
public protocol UULogWriter
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
    func writeToLog(level: UULogLevel, tag: String, message: String)
}
