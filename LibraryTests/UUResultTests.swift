//
//  UUResultTests.swift
//  UUSwiftCore
//
//  Created by Ryan DeVore on 6/8/26.
//

import XCTest
@testable import UUSwiftCore

final class UUResultTests: XCTestCase
{
    // MARK: - uuSuccess

    func test_uuSuccess_returnsValueForSuccess()
    {
        let result: Result<Int, TestError> = .success(42)

        XCTAssertEqual(42, result.uuSuccess)
    }

    func test_uuSuccess_returnsNilForFailure()
    {
        let result: Result<Int, TestError> = .failure(.sample)

        XCTAssertNil(result.uuSuccess)
    }

    func test_uuSuccess_preservesOptionalSuccessValue()
    {
        let result: Result<String?, TestError> = .success("payload")

        XCTAssertEqual("payload", result.uuSuccess)
    }

    func test_uuSuccess_returnsNilOptionalWhenSuccessIsNil()
    {
        let result: Result<String?, TestError> = .success(nil)

        switch result.uuSuccess
        {
            case .none:
                XCTFail("Expected .some(nil) for a successful result with a nil payload")

            case .some(let value):
                XCTAssertNil(value)
        }
    }

    func test_uuSuccess_distinguishesNilPayloadFromFailure()
    {
        let successWithNil: Result<String?, TestError> = .success(nil)
        let failure: Result<String?, TestError> = .failure(.sample)

        if case .none = successWithNil.uuSuccess
        {
            XCTFail("Expected .some(nil) for a successful result with a nil payload")
        }

        if case .some = failure.uuSuccess
        {
            XCTFail("Expected nil for a failed result")
        }
    }

    func test_uuSuccess_worksWithCollectionSuccessType()
    {
        let result: Result<[String], TestError> = .success(["a", "b"])

        XCTAssertEqual(["a", "b"], result.uuSuccess)
    }

    // MARK: - uuFailure

    func test_uuFailure_returnsErrorForFailure()
    {
        let result: Result<Int, TestError> = .failure(.sample)

        XCTAssertEqual(.sample, result.uuFailure)
    }

    func test_uuFailure_returnsNilForSuccess()
    {
        let result: Result<Int, TestError> = .success(7)

        XCTAssertNil(result.uuFailure)
    }

    func test_uuFailure_worksWithCustomErrorMessage()
    {
        let result: Result<Int, TestError> = .failure(TestError(code: 57, message: "network unavailable"))

        XCTAssertEqual(57, result.uuFailure?.code)
        XCTAssertEqual("network unavailable", result.uuFailure?.message)
    }

    func test_uuFailure_preservesStructuredError()
    {
        let error = TestError(code: 503, message: "Service unavailable")
        let result: Result<Void, TestError> = .failure(error)

        XCTAssertEqual(error, result.uuFailure)
    }

    // MARK: - combined

    func test_successAndFailureAreMutuallyExclusive()
    {
        let success: Result<Int, TestError> = .success(1)
        let failure: Result<Int, TestError> = .failure(.sample)

        XCTAssertNotNil(success.uuSuccess)
        XCTAssertNil(success.uuFailure)
        XCTAssertNil(failure.uuSuccess)
        XCTAssertNotNil(failure.uuFailure)
    }
}

private struct TestError: Error, Equatable
{
    let code: Int
    let message: String

    static let sample = TestError(code: 100, message: "boom")

    init(code: Int = 100, message: String = "boom")
    {
        self.code = code
        self.message = message
    }
}
