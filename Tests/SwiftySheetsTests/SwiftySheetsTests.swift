@testable import SwiftySheets
import XCTest

enum TestContstants {
    static let jsonPath = "/dummy/path/service_account.json"
    static let spreadsheetID = "test-spreadsheet-id"
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

    static let allTests = [
        ("testSpreadsheetWithID", testSpreadsheetWithID),
        ("testAllSheetsInSpreadsheet", testAllSheetsInSpreadsheet),
        ("testNamedSheetInSpreadsheet", testNamedSheetInSpreadsheet),
    ]
}
