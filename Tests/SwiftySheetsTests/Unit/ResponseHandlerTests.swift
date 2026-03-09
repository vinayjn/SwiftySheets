@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ResponseHandlerTests: XCTestCase {

    func testValidateAndDecodeSuccess() throws {
        let valueRange = ValueRange(range: "A1:A1", values: [["test"]])
        let data = try JSONEncoder().encode(valueRange)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let result: ValueRange = try ResponseHandler.validateAndDecode(data: data, response: response)
        XCTAssertEqual(result.values, [["test"]])
    }

    func testValidateAndDecodeDecodingError() throws {
        let data = Data("{\"wrong\": true}".utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        do {
            let _: ValueRange = try ResponseHandler.validateAndDecode(data: data, response: response)
            XCTFail("Should throw decodingError")
        } catch SheetsError.decodingError(let context) {
            XCTAssertTrue(context.contains("ValueRange"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMapError401() {
        let error = ResponseHandler.mapError(data: Data(), statusCode: 401, headers: [:])
        if case .authenticationFailed = error {
            // Expected
        } else {
            XCTFail("Expected authenticationFailed, got \(error)")
        }
    }

    func testMapError404() {
        let error = ResponseHandler.mapError(data: Data(), statusCode: 404, headers: [:])
        if case .spreadsheetNotFound = error {
            // Expected
        } else {
            XCTFail("Expected spreadsheetNotFound, got \(error)")
        }
    }

    func testMapError429WithRetryAfter() {
        let error = ResponseHandler.mapError(data: Data(), statusCode: 429, headers: ["Retry-After": "45"])
        if case .rateLimitExceeded(let retryAfter) = error {
            XCTAssertEqual(retryAfter, 45)
        } else {
            XCTFail("Expected rateLimitExceeded, got \(error)")
        }
    }

    func testMapError403PermissionDenied() throws {
        let apiError = GoogleAPIError(
            error: GoogleAPIError.ErrorDetails(
                code: 403,
                message: "Access denied",
                status: "PERMISSION_DENIED",
                details: nil
            )
        )
        let data = try JSONEncoder().encode(apiError)
        let error = ResponseHandler.mapError(data: data, statusCode: 403, headers: [:])
        if case .permissionDenied(let message) = error {
            XCTAssertEqual(message, "Access denied")
        } else {
            XCTFail("Expected permissionDenied, got \(error)")
        }
    }

    func testMapError403Quota() throws {
        let apiError = GoogleAPIError(
            error: GoogleAPIError.ErrorDetails(
                code: 403,
                message: "Rate quota exceeded",
                status: "RESOURCE_EXHAUSTED",
                details: nil
            )
        )
        let data = try JSONEncoder().encode(apiError)
        let error = ResponseHandler.mapError(data: data, statusCode: 403, headers: ["Retry-After": "10"])
        if case .quotaExceeded(let retryAfter) = error {
            XCTAssertEqual(retryAfter, 10)
        } else {
            XCTFail("Expected quotaExceeded, got \(error)")
        }
    }

    func testValidateSuccess() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )!

        // Should not throw
        try ResponseHandler.validate(data: Data(), response: response)
    }

    func testValidateFailure() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!

        do {
            try ResponseHandler.validate(data: Data(), response: response)
            XCTFail("Should throw")
        } catch SheetsError.invalidResponse(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
