@testable import SwiftySheets
import XCTest

final class AsyncSequenceTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
    // MARK: - RowAsyncSequence
    
    func testRowAsyncSequence() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Mock values response
        let valuesResponse = """
        {"range": "A1:B3", "values": [["Row 1", "Value 1"], ["Row 2", "Value 2"], ["Row 3", "Value 3"]]}
        """
        mockSession.mockData = valuesResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        var rows: [[String]] = []
        for try await row in spreadsheet.rows(in: #Range("A1:B3")) {
            rows.append(row)
        }
        
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ["Row 1", "Value 1"])
        XCTAssertEqual(rows[2], ["Row 3", "Value 3"])
    }
    
    // MARK: - TypedRowAsyncSequence
    
    func testTypedRowAsyncSequence() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        // Mock values response
        let valuesResponse = """
        {"range": "A1:B2", "values": [["John Doe", "30"], ["Jane Doe", "25"]]}
        """
        mockSession.mockData = valuesResponse.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        var people: [Person] = []
        for try await person in spreadsheet.stream(Person.self, in: #Range("A1:B2")) {
            people.append(person)
        }
        
        XCTAssertEqual(people.count, 2)
        XCTAssertEqual(people[0].name, "John Doe")
        XCTAssertEqual(people[0].age, "30")
        XCTAssertEqual(people[1].name, "Jane Doe")
        XCTAssertEqual(people[1].age, "25")
    }
    
    func testRowAsyncSequenceError() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        let mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 403, httpVersion: nil, headerFields: nil)
        let apiError = GoogleAPIError(error: GoogleAPIError.ErrorDetails(code: 403, message: "Permission denied", status: "PERMISSION_DENIED", details: nil))
        mockSession.mockData = try! JSONEncoder().encode(apiError)
        mockSession.mockResponse = mockResponse
        
        do {
            for try await _ in spreadsheet.rows(in: #Range("A1:B3")) {
                XCTFail("Should have thrown error")
            }
        } catch SheetsError.permissionDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

@SheetRow
private struct Person: Sendable {
    @Column(index: 0) var name: String
    @Column(index: 1) var age: String
}
