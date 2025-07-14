@testable import SwiftySheets
import XCTest
import Foundation

enum TestContstants {
    static let jsonPath = "/dummy/path/service_account.json"
    static let spreadsheetID = "test-spreadsheet-id"
}

class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}

class MockCredentials: GoogleCredentials {
    func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer mock-token", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }
}

final class SwiftySheetsTests: XCTestCase, @unchecked Sendable {
    private var client: Client!

    override func setUp() async throws {
        try await super.setUp()

        let credentials = try XCTUnwrap(ServiceAccountCredentials(jsonPath: TestContstants.jsonPath))
        client = Client(credentials: credentials)
    }

    func testSpreadsheetWithID() async throws {
        let spreadsheet = try await client.spreadsheet(id: TestContstants.spreadsheetID)
        let values = try await spreadsheet.values(range: "A11")
        XCTAssertEqual(values, [["Liquid Cash"]])
    }

    func testAllSheetsInSpreadsheet() async throws {
        let spreadsheet = try await client.spreadsheet(id: TestContstants.spreadsheetID)
        let sheets = try spreadsheet.sheets()
        XCTAssert(sheets.count > 0)
    }

    func testNamedSheetInSpreadsheet() async throws {
        let spreadsheet = try await client.spreadsheet(id: TestContstants.spreadsheetID)
        let sheet = try spreadsheet.sheet(named: "Sheet1")
        XCTAssertNotNil(sheet)
    }

    // MARK: - Error Handling Tests
    
    func testErrorHandling401() async throws {
        let mockSession = MockURLSession()
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
        let client = Client(credentials: MockCredentials(), session: mockSession)
        
        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown authenticationFailed error")
        } catch SheetsError.authenticationFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testErrorHandling403WithAPIError() async throws {
        let mockSession = MockURLSession()
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )
        
        let apiError = GoogleAPIError(
            error: GoogleAPIError.ErrorDetails(
                code: 403,
                message: "The caller does not have permission",
                status: "PERMISSION_DENIED",
                details: nil
            )
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(apiError)
        
        let client = Client(credentials: MockCredentials(), session: mockSession)
        
        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown permissionDenied error")
        } catch SheetsError.permissionDenied(let message) {
            XCTAssertEqual(message, "The caller does not have permission")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testErrorHandling429WithRetryAfter() async throws {
        let mockSession = MockURLSession()
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
        let client = Client(credentials: MockCredentials(), session: mockSession)
        
        do {
            let _: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
            XCTFail("Should have thrown rateLimitExceeded error")
        } catch SheetsError.rateLimitExceeded(let retryAfter) {
            XCTAssertEqual(retryAfter, 60)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Response Status Code Tests
    
    func testSuccessfulResponseCodes() async throws {
        let mockSession = MockURLSession()
        let successCodes = [200, 201, 204, 299]
        
        let mockValueRange = ValueRange(range: "A1:A1", values: [["test"]])
        let mockData = try JSONEncoder().encode(mockValueRange)
        
        for statusCode in successCodes {
            let mockResponse = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            mockSession.mockResponse = mockResponse
            mockSession.mockData = mockData
            
            let client = Client(credentials: MockCredentials(), session: mockSession)
            
            do {
                let result: ValueRange = try await client.makeRequest(URLRequest(url: URL(string: "https://example.com")!))
                XCTAssertEqual(result.values, [["test"]])
            } catch {
                XCTFail("Should not throw error for status code \(statusCode): \(error)")
            }
        }
    }
    
    // MARK: - Write Operations Tests
    
    func testUpdateValuesRequest() async throws {
        let mockSession = MockURLSession()
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let updateResponse = UpdateValuesResponse(
            spreadsheetId: "test-id",
            updatedRange: "A1:B2",
            updatedRows: 2,
            updatedColumns: 2,
            updatedCells: 4
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(updateResponse)
        
        let client = Client(credentials: MockCredentials(), session: mockSession)
        
        let result = try await client.updateValues(
            spreadsheetId: "test-id",
            range: "A1:B2",
            values: [["A1", "B1"], ["A2", "B2"]]
        )
        
        XCTAssertEqual(result.spreadsheetId, "test-id")
        XCTAssertEqual(result.updatedRange, "A1:B2")
        XCTAssertEqual(result.updatedCells, 4)
    }
    
    func testAppendValuesRequest() async throws {
        let mockSession = MockURLSession()
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let updateResponse = UpdateValuesResponse(
            spreadsheetId: "test-id",
            updatedRange: "A3:B4",
            updatedRows: 2,
            updatedColumns: 2,
            updatedCells: 4
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(updateResponse)
        
        let client = Client(credentials: MockCredentials(), session: mockSession)
        
        let result = try await client.appendValues(
            spreadsheetId: "test-id",
            range: "A1:B1",
            values: [["A3", "B3"], ["A4", "B4"]]
        )
        
        XCTAssertEqual(result.spreadsheetId, "test-id")
        XCTAssertEqual(result.updatedRange, "A3:B4")
    }
    
    func testBatchUpdateRequest() async throws {
        let mockSession = MockURLSession()
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Empty response for batch update
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(EmptyResponse())
        
        let client = Client(credentials: MockCredentials(), session: mockSession)
        
        let addSheetRequest = BatchUpdateRequest.Request.addSheet(
            AddSheetRequest(properties: Sheet.SheetProperties(
                sheetId: 1,
                title: "New Sheet",
                index: 1,
                gridProperties: Sheet.GridProperties(rowCount: 100, columnCount: 10)
            ))
        )
        
        // Should not throw
        try await client.batchUpdate(spreadsheetId: "test-id", requests: [addSheetRequest])
    }
    
    // MARK: - Endpoint Tests
    
    func testUpdateValuesEndpoint() throws {
        let endpoint = Endpoint.updateValues(
            spreadsheetId: "test-id",
            range: "A1:B2",
            valueInputOption: "USER_ENTERED"
        )
        
        let url = try endpoint.url()
        XCTAssertEqual(url.absoluteString, "https://sheets.googleapis.com/v4/spreadsheets/test-id/values/A1:B2?valueInputOption=USER_ENTERED")
        
        let request = try endpoint.request()
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testBatchUpdateEndpoint() throws {
        let endpoint = Endpoint.batchUpdate(spreadsheetId: "test-id")
        
        let url = try endpoint.url()
        XCTAssertEqual(url.absoluteString, "https://sheets.googleapis.com/v4/spreadsheets/test-id:batchUpdate")
        
        let request = try endpoint.request()
        XCTAssertEqual(request.httpMethod, "POST")
    }
    
    func testAppendValuesEndpoint() throws {
        let endpoint = Endpoint.appendValues(
            spreadsheetId: "test-id",
            range: "A1:B1",
            valueInputOption: "RAW"
        )
        
        let url = try endpoint.url()
        XCTAssertEqual(url.absoluteString, "https://sheets.googleapis.com/v4/spreadsheets/test-id/values/A1:B1:append?valueInputOption=RAW")
    }

    static let allTests = [
        ("testSpreadsheetWithID", testSpreadsheetWithID),
        ("testAllSheetsInSpreadsheet", testAllSheetsInSpreadsheet),
        ("testNamedSheetInSpreadsheet", testNamedSheetInSpreadsheet),
        ("testErrorHandling401", testErrorHandling401),
        ("testErrorHandling403WithAPIError", testErrorHandling403WithAPIError),
        ("testErrorHandling429WithRetryAfter", testErrorHandling429WithRetryAfter),
        ("testSuccessfulResponseCodes", testSuccessfulResponseCodes),
        ("testUpdateValuesRequest", testUpdateValuesRequest),
        ("testAppendValuesRequest", testAppendValuesRequest),
        ("testBatchUpdateRequest", testBatchUpdateRequest),
        ("testUpdateValuesEndpoint", testUpdateValuesEndpoint),
        ("testBatchUpdateEndpoint", testBatchUpdateEndpoint),
        ("testAppendValuesEndpoint", testAppendValuesEndpoint),
    ]
}

private struct EmptyResponse: Codable {}
