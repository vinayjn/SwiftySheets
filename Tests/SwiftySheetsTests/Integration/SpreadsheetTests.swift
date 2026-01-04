@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SpreadsheetTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        let transport = SheetsTransport(credentials: credentials, session: mockSession)
        client = Client(transport: transport)
    }
    
    func testSpreadsheetWithID() async throws {
        setupMockSpreadsheetResponse()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let mockValueRange = ValueRange(range: "A11", values: [["Liquid Cash"]])
        mockSession.mockData = try JSONEncoder().encode(mockValueRange)
        
        let values = try await spreadsheet.values(range: #Range("A11"))
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
    
    func testCreateSpreadsheet() async throws {
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: "new-id",
            properties: Spreadsheet.Metadata.Properties(title: "New Sheet"),
            sheets: []
        )
        mockSession.mockResponse = mockResponse
        mockSession.mockData = try JSONEncoder().encode(metadata)
        
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
