@testable import SwiftySheets
import XCTest

final class SheetQueryTests: XCTestCase, @unchecked Sendable {
    private var client: Client!
    private var mockSession: MockURLSession!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        let credentials = MockCredentials()
        client = Client(credentials: credentials, session: mockSession)
    }
    
    func testQueryFilter() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["Alice", "Engineering", "60000", "Active"],
            ["Bob", "Engineering", "55000", "Inactive"],
            ["Charlie", "Marketing", "50000", "Active"],
            ["David", "Engineering", "65000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.department, equals: "Engineering")
            .where(\.status, equals: "Active")
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "Alice")
        XCTAssertEqual(results[1].name, "David")
    }
    
    func testQueryComparison() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["Low", "Engineering", "40000", "Active"],
            ["Mid", "Engineering", "60000", "Active"],
            ["High", "Engineering", "80000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.salaryInt, greaterThan: 50000)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "Mid" })
        XCTAssertTrue(results.contains { $0.name == "High" })
    }
    
    func testQuerySort() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["Charlie", "Marketing", "50000", "Active"],
            ["Alice", "Engineering", "60000", "Active"],
            ["Bob", "Sales", "55000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .sorted(by: \.name)
            .fetch()
        
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].name, "Alice")
        XCTAssertEqual(results[1].name, "Bob")
        XCTAssertEqual(results[2].name, "Charlie")
    }
    
    func testQueryLimit() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["A", "Dept", "1", "Active"],
            ["B", "Dept", "2", "Active"],
            ["C", "Dept", "3", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .limit(2)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "A")
        XCTAssertEqual(results[1].name, "B")
    }
    
    func testQueryWhereContains() async throws {
         setupMockSpreadsheet()
         let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
         
         mockValues([
             ["John Smith", "Dept", "1", "Active"],
             ["Jane Doe", "Dept", "2", "Active"],
             ["Bob Smith", "Dept", "3", "Active"]
         ])
         
         let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
             .where(\.name, contains: "Smith")
             .fetch()
         
         XCTAssertEqual(results.count, 2)
         XCTAssertTrue(results.contains { $0.name == "John Smith" })
         XCTAssertTrue(results.contains { $0.name == "Bob Smith" })
     }
    
    func testQueryCount() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["A", "Dept", "1", "Active"],
            ["B", "Dept", "2", "Active"],
            ["C", "Dept", "3", "Active"]
        ])
        
        let count = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .filter { $0.status == "Active" }
            .count()
        
        XCTAssertEqual(count, 3)
    }
    
    func testQueryFirst() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["First", "Dept", "1", "Active"],
            ["Second", "Dept", "2", "Active"]
        ])
        
        let first = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.name, equals: "First")
            .first()
        
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.name, "First")
        
        // Re-queue response for second query
        mockValues([
            ["First", "Dept", "1", "Active"],
            ["Second", "Dept", "2", "Active"]
        ])
        
        let none = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.name, equals: "NonExistent")
            .first()
        
        XCTAssertNil(none)
    }
    
    // MARK: - Helpers
    
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
    
    private func mockValues(_ values: [[String]]) {
        let valueRange = ValueRange(range: "A:D", values: values)
        mockSession.mockData = try! JSONEncoder().encode(valueRange)
        mockSession.mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
    }
}

@SheetRow
private struct Employee: Sendable {
    @Column(index: 0) var name: String
    @Column(index: 1) var department: String
    @Column(index: 2) var salary: String
    @Column(index: 3) var status: String
    
    var salaryInt: Int {
        Int(salary) ?? 0
    }
}
