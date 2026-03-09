@testable import SwiftySheets
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SpreadsheetValuesTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
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
    
    func testCellAccess() async throws {
        let metadata = Spreadsheet.Metadata(
             spreadsheetId: TestConstants.spreadsheetID,
             properties: Spreadsheet.Metadata.Properties(title: "Test Sheet"),
             sheets: [
                 Sheet(properties: Sheet.SheetProperties(sheetId: 0, title: "Sheet1", index: 0, gridProperties: Sheet.GridProperties(rowCount: 100, columnCount: 20)))
             ]
         )
         mockSession.queue(data: try! JSONEncoder().encode(metadata))

        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)

        let valueRange = ValueRange(range: "A1", values: [["Test"]])
        mockSession.queue(data: try JSONEncoder().encode(valueRange))

        let val = try await spreadsheet.cell(#Range("Sheet1!A1"))
        XCTAssertEqual(val, "Test")
    }
    
    func testTypeSafeUpdateValues() async throws {
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: "id",
            properties: Spreadsheet.Metadata.Properties(title: "Test"),
            sheets: []
        )
        mockSession.queue(data: try JSONEncoder().encode(metadata))
        
        let updateResponse = UpdateValuesResponse(spreadsheetId: "id", updatedRange: "A1", updatedRows: 1, updatedColumns: 3, updatedCells: 3)
        mockSession.queue(data: try JSONEncoder().encode(updateResponse))
        
        let users = [try TestUser(row: ["Alice", "a@b.com", "10"])]
        
        _ = try await client.spreadsheet(id: "id").updateValues(range: #Range("A1"), values: users)
    }
    
    func testTypeSafeAppendValues() async throws {
        let metadata = Spreadsheet.Metadata(
            spreadsheetId: "id",
            properties: Spreadsheet.Metadata.Properties(title: "Test"),
            sheets: []
        )
        mockSession.queue(data: try JSONEncoder().encode(metadata))
        
        let updates = UpdateValuesResponse(spreadsheetId: "id", updatedRange: "A1", updatedRows: 1, updatedColumns: 3, updatedCells: 3)
        let appendResponse = AppendValuesResponse(spreadsheetId: "id", tableRange: "A1", updates: updates)
        mockSession.queue(data: try JSONEncoder().encode(appendResponse))
        
        let users = [try TestUser(row: ["Bob", "b@c.com", "20"])]
        
        _ = try await client.spreadsheet(id: "id").appendValues(range: #Range("A1"), values: users)
    }
}

@SheetRow
struct TestUser {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column("C") var points: Int
}
