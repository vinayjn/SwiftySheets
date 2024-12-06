@testable import SwiftySheets
import XCTest

@available(macOS 13.0, *)
final class SwiftySheetsTests: XCTestCase, @unchecked Sendable {
    
    func testSpreadsheetWithID() async throws {
      let credentials = try XCTUnwrap(try ServiceAccountCredentials(jsonPath: "/dummy/path/service_account.json"))
      
      let client = SheetsClient(credentials: credentials)
      
      let sheet = client.getSpreadsheet(id: "test-spreadsheet-id")
      
      let values = try await sheet.getValues(range: "A11")
      XCTAssertEqual(values.count, 1)
      print(values)
    }
    
    static let allTests = [
        ("testSpreadsheetWithID", testSpreadsheetWithID)
    ]
}
