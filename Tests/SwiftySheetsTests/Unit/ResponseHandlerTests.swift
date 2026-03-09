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

    // MARK: - SafeString Null Handling

    func testValueRangeDecodesNullCells() throws {
        // JSON with null values mixed in — Google Sheets can return these
        let json = """
        {"range": "A1:B2", "values": [["hello", null, "world"], [null, "test"]]}
        """
        let data = Data(json.utf8)
        let valueRange = try JSONDecoder().decode(ValueRange.self, from: data)

        XCTAssertEqual(valueRange.values.count, 2)
        XCTAssertEqual(valueRange.values[0], ["hello", "", "world"])
        XCTAssertEqual(valueRange.values[1], ["", "test"])
    }

    func testValueRangeDecodesNumericCells() throws {
        let json = """
        {"range": "A1:C1", "values": [[42, 3.14, true]]}
        """
        let data = Data(json.utf8)
        let valueRange = try JSONDecoder().decode(ValueRange.self, from: data)

        XCTAssertEqual(valueRange.values[0][0], "42")
        XCTAssertEqual(valueRange.values[0][1], "3.14")
        XCTAssertEqual(valueRange.values[0][2], "true")
    }

    func testValueRangeDecodesEmptyValues() throws {
        let json = """
        {"range": "A1:A1", "values": []}
        """
        let data = Data(json.utf8)
        let valueRange = try JSONDecoder().decode(ValueRange.self, from: data)
        XCTAssertEqual(valueRange.values.count, 0)
    }

    // MARK: - SheetsError Descriptions

    func testSheetsErrorLocalizedDescriptions() {
        let cases: [(SheetsError, String)] = [
            (.authenticationFailed, "Authentication failed"),
            (.invalidRequest, "request could not be constructed"),
            (.networkError("timeout"), "timeout"),
            (.spreadsheetNotFound(message: "bad id"), "bad id"),
            (.sheetNotFound(message: "Sheet2"), "Sheet2"),
            (.invalidRange(message: "bad col"), "bad col"),
            (.decodingError(context: "row 5"), "row 5"),
            (.invalidResponse(status: 502), "502"),
            (.permissionDenied(message: "no access"), "no access"),
            (.rateLimitExceeded(retryAfter: 30), "30"),
            (.rateLimitExceeded(retryAfter: nil), "Rate limit exceeded"),
            (.quotaExceeded(retryAfter: 60), "60"),
            (.quotaExceeded(retryAfter: nil), "Quota exceeded"),
            (.invalidCredentials(message: "bad json"), "bad json"),
        ]

        for (error, substring) in cases {
            let description = error.localizedDescription
            XCTAssertTrue(
                description.contains(substring),
                "\(error) description '\(description)' should contain '\(substring)'"
            )
        }
    }

    func testSheetsErrorApiErrorDescription() throws {
        let apiError = GoogleAPIError(
            error: GoogleAPIError.ErrorDetails(
                code: 500,
                message: "Internal error",
                status: "INTERNAL",
                details: nil
            )
        )
        let error = SheetsError.apiError(apiError)
        let description = error.localizedDescription
        XCTAssertTrue(description.contains("500"))
        XCTAssertTrue(description.contains("Internal error"))
    }
}
