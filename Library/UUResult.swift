//
//  UUResult.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/8/26.
//

import Foundation

public extension Result
{
    /// Returns the success value when this result is `.success`, otherwise `nil`.
    ///
    /// When `Success` is itself optional, the returned optional distinguishes a failed result
    /// (`nil`) from a successful result whose payload is `nil` (`.some(nil)`).
    ///
    /// Use ``uuFailure`` to extract the error from a failed result.
    var uuSuccess: Success?
    {
        switch self
        {
            case .success(let value):
                return .some(value)

            case .failure:
                return nil
        }
    }

    /// Returns the failure value when this result is `.failure`, otherwise `nil`.
    ///
    /// Use ``uuSuccess`` to extract the payload from a successful result.
    var uuFailure: Failure?
    {
        switch self
        {
            case .success:
                return nil

            case .failure(let value):
                return .some(value)
        }
    }
}
