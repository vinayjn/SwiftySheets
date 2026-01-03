@testable import SwiftySheets
import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum TestConstants {
    static let jsonPath = "/dummy/path/service_account.json"
    static let spreadsheetID = "test-spreadsheet-id"
}

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var responseQueue: [(Data, URLResponse, Error?)] = []
    
    // Legacy support: Setting these resets the queue to a single item
    var mockData: Data? {
        didSet { updateSingleItemQueue() }
    }
    var mockResponse: URLResponse? {
        didSet { updateSingleItemQueue() }
    }
    var mockError: Error? {
        didSet { updateSingleItemQueue() }
    }
    
    private func updateSingleItemQueue() {
        // If we are setting legacy props, we assume a single response scenario
        let d = mockData ?? Data()
        let r = mockResponse ?? HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responseQueue = [(d, r, mockError)]
    }
    
    func queue(data: Data, response: URLResponse? = nil, error: Error? = nil) {
        let resp = response ?? HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        responseQueue.append((data, resp, error))
    }
    
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        if !responseQueue.isEmpty {
            let (data, response, error) = responseQueue.removeFirst()
            if let error = error { throw error }
            return (data, response)
        }
        // Fallback or error
        return (Data(), HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

final class MockCredentials: GoogleCredentials, @unchecked Sendable {
    func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer mock-token", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }
}

final class SwiftySheetsTests: XCTestCase, @unchecked Sendable {
    private var client: Client!

    private var mockSession: MockURLSession!

    override func setUp() async throws {
        try await super.setUp()
        
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        // We use the convenience init that uses SheetsTransport internally, 
        // OR we manually build transport to inject mock session.
        let transport = SheetsTransport(credentials: credentials, session: mockSession)
        client = Client(transport: transport)
    }

    func testSpreadsheetWithID() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Mock response for values call
        let mockValueRange = ValueRange(range: "A11", values: [["Liquid Cash"]])
        mockSession.mockData = try JSONEncoder().encode(mockValueRange)
        
        let values = try await spreadsheet.values(range: "A11")
        XCTAssertEqual(values, [["Liquid Cash"]])
    }

    func testAllSheetsInSpreadsheet() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        let sheets = try spreadsheet.sheets()
        XCTAssert(sheets.count > 0)
    }

    func testNamedSheetInSpreadsheet() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        let sheet = try spreadsheet.sheet(named: "Sheet1")
        XCTAssertNotNil(sheet)
    }
    
    private func setupMockSpreadsheetResponse() {
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: TestConstants.spreadsheetID,
            properties: Spreadsheet.Metadata.Properties(title: "Test Sheet"),
            sheets: [
                Sheet(properties: Sheet.SheetProperties(sheetId: 0, title: "Sheet1", index: 0, gridProperties: Sheet.GridProperties(rowCount: 100, columnCount: 20)))
            ]
        )
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.mockData = try! JSONEncoder().encode(metadata)
    }

    // MARK: - Error Handling Tests
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling401() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
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
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
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
        let appendResponse = AppendValuesResponse(spreadsheetId: "test-id", tableRange: "A1:B2", updates: updateResponse)
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(appendResponse)
        
        let result = try await client.appendValues(
            spreadsheetId: "test-id",
            range: "A1:B1",
            values: [["A3", "B3"], ["A4", "B4"]]
        )
        
        XCTAssertEqual(result.spreadsheetId, "test-id")
        XCTAssertEqual(result.updatedRange, "A3:B4")
    }
    
    func testBatchUpdateRequest() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Mock response for batch update
        let mockResponseData = BatchUpdateResponse(
            spreadsheetId: "test-id",
            replies: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(mockResponseData)
        
        let addSheetRequest = BatchUpdateRequest.Request.addSheet(
            AddSheetRequest(properties: Sheet.Draft(
                title: "New Sheet",
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
        XCTAssertEqual(request.httpMethod, "PUT")
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

    func testSheetRange() {
        // Test String Literal Parsing
        let range1: SheetRange = "Sheet1!A1:B2"
        XCTAssertEqual(range1.sheetName, "Sheet1")
        XCTAssertEqual(range1.startColumn, "A")
        XCTAssertEqual(range1.startRow, 1)
        XCTAssertEqual(range1.endColumn, "B")
        XCTAssertEqual(range1.endRow, 2)
        XCTAssertEqual(range1.description, "Sheet1!A1:B2")
        
        let range2: SheetRange = "Sheet2!C5"
        XCTAssertEqual(range2.sheetName, "Sheet2")
        XCTAssertEqual(range2.startColumn, "C")
        XCTAssertEqual(range2.startRow, 5)
        XCTAssertNil(range2.endColumn)
        XCTAssertNil(range2.endRow)
        XCTAssertEqual(range2.description, "Sheet2!C5")
        
        let range3: SheetRange = "A1:Z100" // No sheet name
        XCTAssertNil(range3.sheetName)
        XCTAssertEqual(range3.startColumn, "A")
        XCTAssertEqual(range3.startRow, 1)
        XCTAssertEqual(range3.endColumn, "Z")
        XCTAssertEqual(range3.endRow, 100)
        XCTAssertEqual(range3.description, "A1:Z100")
        
        // Test Init
        let range4 = SheetRange(sheetName: "Sheet3", startColumn: "AA", startRow: 10)
        XCTAssertEqual(range4.description, "Sheet3!AA10")
        
        let range5 = SheetRange(stringLiteral: "WrongFormat")
        XCTAssertNil(range5.sheetName)
        XCTAssertEqual(range5.startColumn, "WrongFormat")
        XCTAssertNil(range5.startRow)
    }
    
    func testBatchUpdateDSL() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(BatchUpdateResponse(spreadsheetId: "test-id", replies: nil))
        
        try await client.batchUpdate(spreadsheetId: "test-id") {
            AddSheet("New Sheet")
            DeleteSheet(id: 123)
        }
        
        // Keep in mind we are not verifyng the Request Body content here easily without spying on Transport
        // To verify the body, we would need to inspect 'mockSession.lastRequest' if we added that capability.
        // For now, we verify it doesn't crash.
    }
    
    // Test Macro Usage
    func testSheetRowMacro() throws {
        let row = ["Alice", "alice@example.com", "100"]
        let user = try TestUser(row: row)
        XCTAssertEqual(user.name, "Alice")
        XCTAssertEqual(user.email, "alice@example.com")
        XCTAssertEqual(user.points, 100)
        
        let encoded = try user.encodeRow()
        XCTAssertEqual(encoded, ["Alice", "alice@example.com", "100"])
    }
    
    func testInitEquality() throws {
        // Init via Row Array
        let row = ["Alice", "alice@example.com", "100"]
        let userFromRow = try TestUser(row: row)
        
        // Init via Memberwise
        let userFromProps = TestUser(name: "Alice", email: "alice@example.com", points: 100)
        
        // Verify properties match
        XCTAssertEqual(userFromRow.name, userFromProps.name)
        XCTAssertEqual(userFromRow.email, userFromProps.email)
        XCTAssertEqual(userFromRow.points, userFromProps.points)
        
        // Verify Equatable conformance (Synthesized)
        // Note: XCTAssertEqual requires Equatable.
        XCTAssertEqual(userFromRow, userFromProps)
    }
    
    func testTypeSafeUpdateValues() async throws {
        // 1. Queue Metadata Response
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: "id",
            properties: Spreadsheet.Metadata.Properties(title: "Test"),
            sheets: []
        )
        mockSession.queue(data: try JSONEncoder().encode(metadata))
        
        // 2. Queue Update Response
        let updateResponse = UpdateValuesResponse(spreadsheetId: "id", updatedRange: "A1", updatedRows: 1, updatedColumns: 3, updatedCells: 3)
        mockSession.queue(data: try JSONEncoder().encode(updateResponse))
        
        let users = [try TestUser(row: ["Alice", "a@b.com", "10"])]
        
        _ = try await client.spreadsheet(id: "id").updateValues(range: "A1", values: users)
    }
    
    func testTypeSafeAppendValues() async throws {
        // 1. Queue Metadata Response
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: "id",
            properties: Spreadsheet.Metadata.Properties(title: "Test"),
            sheets: []
        )
        mockSession.queue(data: try JSONEncoder().encode(metadata))
        
        // 2. Queue Append Response
        let updates = UpdateValuesResponse(spreadsheetId: "id", updatedRange: "A1", updatedRows: 1, updatedColumns: 3, updatedCells: 3)
        let appendResponse = AppendValuesResponse(spreadsheetId: "id", tableRange: "A1", updates: updates)
        mockSession.queue(data: try JSONEncoder().encode(appendResponse))
        
        let users = [try TestUser(row: ["Bob", "b@c.com", "20"])]
        
        _ = try await client.spreadsheet(id: "id").appendValues(range: "A1", values: users)
    }


    
    func testCreateSpreadsheet() async throws {
        // ... (existing testCreateSpreadsheet code) ...
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        // ... (rest of create test) ...
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: "new-id",
            properties: Spreadsheet.Metadata.Properties(title: "New Sheet"),
            sheets: []
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(metadata)
        
        // This implicitly tests deserialization of the response and request construction
        let sheet = try await client.createSpreadsheet(title: "New Sheet")
        XCTAssertEqual(sheet.metadata.spreadsheetId, "new-id")
        XCTAssertEqual(sheet.metadata.properties.title, "New Sheet")
    }

    func testDeleteSpreadsheet() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = Data()
        
        // Should not throw
        try await client.deleteSpreadsheet(id: "del-id")
    }
    
    func testListSpreadsheets() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let fileList = DriveFileList(files: [
             DriveFile(id: "id1", name: "Sheet 1", mimeType: "application/vnd.google-apps.spreadsheet"),
             DriveFile(id: "id2", name: "Sheet 2", mimeType: "application/vnd.google-apps.spreadsheet")
        ])
        
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(fileList)
        
        let validFiles = try await client.listSpreadsheets()
        XCTAssertEqual(validFiles.count, 2)
        XCTAssertEqual(validFiles[0].name, "Sheet 1")
    }
    
    func testFormatting() async throws {
        // Mock metadata response for spreadsheet init (implicitly called by spreadsheet(id:))
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        // BatchUpdate response
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(BatchUpdateResponse(spreadsheetId: TestConstants.spreadsheetID))
        
        let format = CellFormat(backgroundColor: .red)
        try await spreadsheet.format(range: "Sheet1!A1", format: format)
        
        // We assume success if no error thrown and request structure is correct (which we can't fully inspect without a spy, but encoding is checked).
    }
    
    func testClearValues() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let response = ClearValuesResponse(spreadsheetId: TestConstants.spreadsheetID, clearedRange: "Sheet1!A1")
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(response)
        
        let result = try await client.clearValues(spreadsheetId: TestConstants.spreadsheetID, range: "Sheet1!A1")
        XCTAssertEqual(result.clearedRange, "Sheet1!A1")
    }
    
    func testSort() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(BatchUpdateResponse(spreadsheetId: TestConstants.spreadsheetID))
        
        try await spreadsheet.sort(range: "Sheet1!A1:C10", column: 0, ascending: true)
    }
    
    func testCellAccess() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Mock simple value response
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let valueRange = ValueRange(range: "A1", values: [["Test"]])
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(valueRange)
        
        let val = try await spreadsheet.cell(sheet: "Sheet1", row: 1, column: 1)
        XCTAssertEqual(val, "Test")
    }
    
    func testResize() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(BatchUpdateResponse(spreadsheetId: TestConstants.spreadsheetID))
        
        try await spreadsheet.resize(sheetId: 0, rows: 100, columns: 20)
    }
    
    func testDSLHelpers() {
        // Only testing request generation, no network needed
        let gridProps = Sheet.GridProperties(rowCount: 100, columnCount: 20)
        let sheetProps = Sheet.SheetProperties(sheetId: 123, title: "Test", index: 0, gridProperties: gridProps)
        let sheet = Sheet(properties: sheetProps)
        
        let requests = BatchUpdateBuilder.buildBlock(
            FormatCells(sheet: sheet, range: "A1", format: CellFormat(backgroundColor: .red)),
            SortRange(sheet: sheet, range: "A2:C", column: 0),
            ResizeSheet(sheet: sheet, rows: 50, columns: 5)
        )
        
        XCTAssertEqual(requests.count, 3)
        // Could inspect request types but enum associated values are hard to check directly without Equatable
        // We trust the helpers call the correct initializers which are tested via integration tests/demo
    }
}

@SheetRow
struct TestUser: SheetRowCodable, Equatable {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column(index: 2) var points: Int
}

private struct EmptyResponse: Codable {}
