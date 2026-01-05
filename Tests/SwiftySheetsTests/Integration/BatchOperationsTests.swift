@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class BatchOperationsTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
    func testBatchUpdateRequest() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
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
        
        try await client.batchUpdate(spreadsheetId: "test-id", requests: [addSheetRequest])
    }
    
    func testBatchUpdateDSL() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(BatchUpdateResponse(spreadsheetId: TestConstants.spreadsheetID, replies: nil))
        
        try await client.batchUpdate(spreadsheetId: "test-id") {
            AddSheet("New Sheet")
            DeleteSheet(id: 123)
        }
    }
    
    func testFormatting() async throws {
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
        
        let format = CellFormat(backgroundColor: .red)
        try await spreadsheet.format(range: #Range("Sheet1!A1"), format: format)
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
        
        try await spreadsheet.sort(range: #Range("Sheet1!A1:C10"), column: 0, ascending: true)
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
}
