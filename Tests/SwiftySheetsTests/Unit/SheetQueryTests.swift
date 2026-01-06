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
    
    // MARK: - New Query Operation Tests
    
    func testQueryNotEquals() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["Alice", "Engineering", "60000", "Active"],
            ["Bob", "Engineering", "55000", "Deleted"],
            ["Charlie", "Marketing", "50000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.status, notEquals: "Deleted")
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertFalse(results.contains { $0.name == "Bob" })
    }
    
    func testQueryGreaterThanOrEquals() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["A", "Dept", "49000", "Active"],
            ["B", "Dept", "50000", "Active"],
            ["C", "Dept", "51000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.salaryInt, greaterThanOrEquals: 50000)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "B" })
        XCTAssertTrue(results.contains { $0.name == "C" })
    }
    
    func testQueryLessThanOrEquals() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["A", "Dept", "49000", "Active"],
            ["B", "Dept", "50000", "Active"],
            ["C", "Dept", "51000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.salaryInt, lessThanOrEquals: 50000)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "A" })
        XCTAssertTrue(results.contains { $0.name == "B" })
    }
    
    func testQueryBetween() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["A", "Dept", "40000", "Active"],
            ["B", "Dept", "55000", "Active"],
            ["C", "Dept", "70000", "Active"],
            ["D", "Dept", "90000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.salaryInt, between: 50000...75000)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "B" })
        XCTAssertTrue(results.contains { $0.name == "C" })
    }
    
    func testQueryStartsWith() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["admin@company.com", "Dept", "1", "Active"],
            ["user@company.com", "Dept", "2", "Active"],
            ["admin_backup@company.com", "Dept", "3", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.name, startsWith: "admin")
            .fetch()
        
        XCTAssertEqual(results.count, 2)
    }
    
    func testQueryEndsWith() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["alice@company.com", "Dept", "1", "Active"],
            ["bob@external.org", "Dept", "2", "Active"],
            ["charlie@company.com", "Dept", "3", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.name, endsWith: "@company.com")
            .fetch()
        
        XCTAssertEqual(results.count, 2)
    }
    
    func testQueryThenSortedBy() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["Charlie", "Engineering", "50000", "Active"],
            ["Alice", "Engineering", "60000", "Active"],
            ["Bob", "Marketing", "55000", "Active"],
            ["David", "Engineering", "45000", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .sorted(by: \.department)
            .thenSorted(by: \.name)
            .fetch()
        
        // Engineering comes first (alphabetically), then Marketing
        // Within Engineering: Alice, Charlie, David (alphabetically)
        XCTAssertEqual(results[0].name, "Alice")
        XCTAssertEqual(results[1].name, "Charlie")
        XCTAssertEqual(results[2].name, "David")
        XCTAssertEqual(results[3].name, "Bob")
    }
    
    func testQueryOffset() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["A", "Dept", "1", "Active"],
            ["B", "Dept", "2", "Active"],
            ["C", "Dept", "3", "Active"],
            ["D", "Dept", "4", "Active"],
            ["E", "Dept", "5", "Active"]
        ])
        
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .offset(2)
            .limit(2)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "C")
        XCTAssertEqual(results[1].name, "D")
    }
    
    func testQueryComplexCombination() async throws {
        setupMockSpreadsheet()
        let spreadsheet = try await client.spreadsheet(id: TestConstants.spreadsheetID)
        
        mockValues([
            ["Alice", "Engineering", "80000", "Active"],
            ["Bob", "Engineering", "50000", "Inactive"],
            ["Charlie", "Marketing", "60000", "Active"],
            ["David", "Engineering", "70000", "Active"],
            ["Eve", "Engineering", "90000", "Active"]
        ])
        
        // Filter: Engineering + Active + salary between 60k-85k, sorted by salary desc, limit 2
        let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
            .where(\.department, equals: "Engineering")
            .where(\.status, equals: "Active")
            .where(\.salaryInt, between: 60000...85000)
            .sorted(by: \.salaryInt, ascending: false)
            .limit(2)
            .fetch()
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "Alice")  // 80k
        XCTAssertEqual(results[1].name, "David")  // 70k
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

