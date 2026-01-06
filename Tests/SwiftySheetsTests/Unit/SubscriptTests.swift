@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SubscriptTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
    // MARK: - CellAccessor Tests
    
    func testCellAccessorGet() async throws {
        // Setup mock spreadsheet metadata
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Setup mock values response
        let valuesResponse = """
        {"range": "A1", "values": [["Hello"]]}
        """
        mockSession.mockData = valuesResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // Test subscript access
        let accessor = spreadsheet["A1"]
        let value = try await accessor.get()
        
        XCTAssertEqual(value, "Hello")
    }
    
    func testCellAccessorSet() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Setup mock update response
        let updateResponse = """
        {"spreadsheetId": "test-id", "updatedRange": "A1", "updatedRows": 1, "updatedColumns": 1, "updatedCells": 1}
        """
        mockSession.mockData = updateResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        // Test subscript set
        let accessor = spreadsheet["A1"]
        try await accessor.set("World")
        // If no error thrown, test passes
    }
    
    func testCellAccessorRowColumn() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Create accessor using row/column
        let accessor = spreadsheet[1, 1] // A1
        
        // Setup mock response
        let valuesResponse = """
        {"range": "A1", "values": [["Cell Value"]]}
        """
        mockSession.mockData = valuesResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let value = try await accessor.get()
        XCTAssertEqual(value, "Cell Value")
    }
    
    func testCellAccessorWithColumn26() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Column 26 = Z
        let accessor = spreadsheet[1, 26]
        
        let valuesResponse = """
        {"range": "Z1", "values": [["Z Column"]]}
        """
        mockSession.mockData = valuesResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let value = try await accessor.get()
        XCTAssertEqual(value, "Z Column")
    }
    
    // MARK: - RangeAccessor Tests
    
    func testRangeAccessorGet() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let valuesResponse = """
        {"range": "A1:B2", "values": [["A1", "B1"], ["A2", "B2"]]}
        """
        mockSession.mockData = valuesResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let accessor = spreadsheet[#Range("A1:B2")]
        let values = try await accessor.get()
        
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0], ["A1", "B1"])
        XCTAssertEqual(values[1], ["A2", "B2"])
    }
    
    func testRangeAccessorSet() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let updateResponse = """
        {"spreadsheetId": "test-id", "updatedRange": "A1:B2", "updatedRows": 2, "updatedColumns": 2, "updatedCells": 4}
        """
        mockSession.mockData = updateResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let accessor = spreadsheet[#Range("A1:B2")]
        try await accessor.set([["New A1", "New B1"], ["New A2", "New B2"]])
        // If no error thrown, test passes
    }
    
    func testRangeAccessorClear() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let clearResponse = """
        {"spreadsheetId": "test-id", "clearedRange": "A1:B2"}
        """
        mockSession.mockData = clearResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let accessor = spreadsheet[#Range("A1:B2")]
        try await accessor.clear()
        // If no error thrown, test passes
    }
    
    // MARK: - Helper
    
    private func setupMockSpreadsheet() {
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: TestConstants.spreadsheetID,
            properties: Spreadsheet.Metadata.Properties(title: "Test Sheet"),
            sheets: [
                Sheet(properties: Sheet.SheetProperties(sheetId: 0, title: "Sheet1", index: 0, gridProperties: Sheet.GridProperties(rowCount: 100, columnCount: 26)))
            ]
        )
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        mockSession.mockData = try! JSONEncoder().encode(metadata)
    }
}
