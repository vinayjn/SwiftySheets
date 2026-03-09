@testable import SwiftySheets
import XCTest

final class SheetRangeTests: XCTestCase {
    
    func testSheetRange() throws {
        // Test String Literal Parsing
        let range1 = try SheetRange(parsing: "Sheet1!A1:B2")
        XCTAssertEqual(range1.sheetName, "Sheet1")
        XCTAssertEqual(range1.startColumn, "A")
        XCTAssertEqual(range1.startRow, 1)
        XCTAssertEqual(range1.endColumn, "B")
        XCTAssertEqual(range1.endRow, 2)
        XCTAssertEqual(range1.description, "Sheet1!A1:B2")
        
        let range2 = try SheetRange(parsing: "Sheet2!C5")
        XCTAssertEqual(range2.sheetName, "Sheet2")
        XCTAssertEqual(range2.startColumn, "C")
        XCTAssertEqual(range2.startRow, 5)
        XCTAssertNil(range2.endColumn)
        XCTAssertNil(range2.endRow)
        XCTAssertEqual(range2.description, "Sheet2!C5")
        
        let range3 = try SheetRange(parsing: "A1:Z100") // No sheet name
        XCTAssertNil(range3.sheetName)
        XCTAssertEqual(range3.startColumn, "A")
        XCTAssertEqual(range3.startRow, 1)
        XCTAssertEqual(range3.endColumn, "Z")
        XCTAssertEqual(range3.endRow, 100)
        XCTAssertEqual(range3.description, "A1:Z100")
        
        // Test Init
        let range4 = SheetRange(sheetName: "Sheet3", startColumn: "AA", startRow: 10)
        XCTAssertEqual(range4.description, "Sheet3!AA10")
    }
    
    func testQuotedSheetNameParsing() throws {
        // Single-quoted sheet names (Google Sheets format for names with spaces)
        let range = try SheetRange(parsing: "'My Sheet'!A1:B2")
        XCTAssertEqual(range.sheetName, "My Sheet")
        XCTAssertEqual(range.startColumn, "A")
        XCTAssertEqual(range.startRow, 1)
        XCTAssertEqual(range.endColumn, "B")
        XCTAssertEqual(range.endRow, 2)
    }

    func testQuotedSheetNameWithSpecialChars() throws {
        let range = try SheetRange(parsing: "'Q1 (2024)'!C3:D10")
        XCTAssertEqual(range.sheetName, "Q1 (2024)")
        XCTAssertEqual(range.startColumn, "C")
        XCTAssertEqual(range.startRow, 3)
        XCTAssertEqual(range.endColumn, "D")
        XCTAssertEqual(range.endRow, 10)
    }

    func testUnquotedSheetNameUnchanged() throws {
        let range = try SheetRange(parsing: "Sheet1!A1:B2")
        XCTAssertEqual(range.sheetName, "Sheet1")
    }

    func testInvalidRangeThrows() {
        // "ABC" is all letters, so it's treated as a column with no row
        XCTAssertNoThrow(try SheetRange(parsing: "ABC"))
        
        // Use explicit Int/String types to call throwing init (not literal init)
        let invalidRow: Int = -1
        let invalidColumn: String = "123"
        
        XCTAssertThrowsError(try SheetRowIndex(invalidRow))
        XCTAssertThrowsError(try SheetColumn(invalidColumn))
    }
}
