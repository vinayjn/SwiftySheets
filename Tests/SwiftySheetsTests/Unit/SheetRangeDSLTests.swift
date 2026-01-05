import XCTest
import SwiftySheets
#if canImport(SwiftySheetsMacros)
import SwiftySheetsMacros
#endif

final class SheetRangeDSLTests: XCTestCase {
    
    // MARK: - Primitives Tests
    
    func testSheetColumnValidation() throws {
        // Valid - these should not throw
        let colA = try SheetColumn("A" as String)  // Explicit String to use throwing init
        XCTAssertEqual(colA.value, "A")
        
        let colZ = try SheetColumn("Z" as String)
        XCTAssertEqual(colZ.value, "Z")
        
        let colAA = try SheetColumn("AA" as String)
        XCTAssertEqual(colAA.value, "AA")
        
        // Lowercase should be uppercased
        let colLower = try SheetColumn("az" as String)
        XCTAssertEqual(colLower.value, "AZ")
        
        // String literal usage (uses ExpressibleByStringLiteral)
        let literal: SheetColumn = "A"
        XCTAssertEqual(literal.value, "A")
        
        // Invalid (should throw) - must use String type to call throwing init
        let invalidNumbers: String = "123"
        let invalidMixed: String = "A1"
        let invalidEmpty: String = ""
        
        XCTAssertThrowsError(try SheetColumn(invalidNumbers))
        XCTAssertThrowsError(try SheetColumn(invalidMixed))
        XCTAssertThrowsError(try SheetColumn(invalidEmpty))
    }
    
    func testSheetRowIndexValidation() throws {
        let row1 = try SheetRowIndex(1 as Int)  // Explicit Int to use throwing init
        XCTAssertEqual(row1.value, 1)
        
        let row100 = try SheetRowIndex(100 as Int)
        XCTAssertEqual(row100.value, 100)
        
        // Integer literal usage
        let literal: SheetRowIndex = 1
        XCTAssertEqual(literal.value, 1)
        
        // Invalid (should throw)
        let invalidZero: Int = 0
        let invalidNegative: Int = -1
        
        XCTAssertThrowsError(try SheetRowIndex(invalidZero))
        XCTAssertThrowsError(try SheetRowIndex(invalidNegative))
    }
    
    // MARK: - SheetRange String Literal Tests
    
    func testStringLiteralParsing() throws {
        // Full range
        let range1 = try SheetRange(parsing: "Sheet1!A1:B2")
        XCTAssertEqual(range1.sheetName, "Sheet1")
        XCTAssertEqual(range1.startColumn?.value, "A")
        XCTAssertEqual(range1.startRow?.value, 1)
        XCTAssertEqual(range1.endColumn?.value, "B")
        XCTAssertEqual(range1.endRow?.value, 2)
        XCTAssertEqual(range1.description, "Sheet1!A1:B2")
        
        // Single cell
        let range2 = try SheetRange(parsing: "A1")
        XCTAssertNil(range2.sheetName)
        XCTAssertEqual(range2.startColumn?.value, "A")
        XCTAssertEqual(range2.startRow?.value, 1)
        XCTAssertNil(range2.endColumn)
        XCTAssertNil(range2.endRow)
        
        // Column only (open row)
        let range3 = try SheetRange(parsing: "A:B")
        XCTAssertEqual(range3.startColumn?.value, "A")
        XCTAssertNil(range3.startRow)
        XCTAssertEqual(range3.endColumn?.value, "B")
        XCTAssertNil(range3.endRow)
        
        // With sheet name
        let range4 = try SheetRange(parsing: "Sheet1!A1")
        XCTAssertEqual(range4.sheetName, "Sheet1")
        XCTAssertEqual(range4.startColumn?.value, "A")
    }
    
    // MARK: - Fluent Builder Tests
    
    func testFluentBuilder() {
        // 1. Root -> From -> To
        let range = SheetRange.root("Data")
            .from(col: "A", row: 1)
            .to(col: "Z", row: 100)
            
        XCTAssertEqual(range.sheetName, "Data")
        XCTAssertEqual(range.startColumn?.value, "A")
        XCTAssertEqual(range.startRow?.value, 1)
        XCTAssertEqual(range.endColumn?.value, "Z")
        XCTAssertEqual(range.endRow?.value, 100)
        XCTAssertEqual(range.description, "Data!A1:Z100")
        
        // 2. Partial usage (Column only)
        let cols = SheetRange.root()
            .from(col: "A")
            .to(col: "C")
            
        XCTAssertEqual(cols.description, "A:C")
        
        // 3. Typed usage validation
        let c: SheetColumn = "X"
        let r: SheetRowIndex = 5
        let typed = SheetRange.root().from(col: c, row: r)
        XCTAssertEqual(typed.description, "X5")
    }
    
    // MARK: - Macro Tests
    
    func testRangeMacroUsage() {
        // This tests that the macro expands to a valid SheetRange object.
        let r = #Range("Sheet1!A1:B2")
        XCTAssertEqual(r.sheetName, "Sheet1")
        XCTAssertEqual(r.startColumn?.value, "A")
        XCTAssertEqual(r.endRow?.value, 2)
        
        let cell = #Range("Z99")
        XCTAssertEqual(cell.description, "Z99")
    }
}
