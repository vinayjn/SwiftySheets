import XCTest
import SwiftySheets
#if canImport(SwiftySheetsMacros)
import SwiftySheetsMacros
#endif

final class SheetRangeDSLTests: XCTestCase {
    
    // MARK: - Primitives Tests
    
    func testSheetColumnValidation() {
        // Valid
        XCTAssertNoThrow(SheetColumn("A"))
        XCTAssertNoThrow(SheetColumn("Z"))
        XCTAssertNoThrow(SheetColumn("AA"))
        XCTAssertNoThrow(SheetColumn("AZ"))
        
        let colA: SheetColumn = "A"
        XCTAssertEqual(colA.value, "A")
        
        // Invalid (Runtime crash - cannot test fatalError easily in XCTest native, but we document intent)
        // defined behavior: crashes on invalid input.
        // Valid inputs are strictly letters.
    }
    
    func testSheetRowIndexValidation() {
        XCTAssertNoThrow(SheetRowIndex(1))
        XCTAssertNoThrow(SheetRowIndex(100))
        
        let row1: SheetRowIndex = 1
        XCTAssertEqual(row1.value, 1)
        
        // Invalid: 0 or negative
        // SheetRowIndex(0) // Should crash
    }
    
    // MARK: - SheetRange String Literal Tests
    
    func testStringLiteralParsing() {
        // Full range
        let range1 = SheetRange(parsing: "Sheet1!A1:B2")
        XCTAssertEqual(range1.sheetName, "Sheet1")
        XCTAssertEqual(range1.startColumn?.value, "A")
        XCTAssertEqual(range1.startRow?.value, 1)
        XCTAssertEqual(range1.endColumn?.value, "B")
        XCTAssertEqual(range1.endRow?.value, 2)
        XCTAssertEqual(range1.description, "Sheet1!A1:B2")
        
        // Single cell
        let range2 = SheetRange(parsing: "A1")
        XCTAssertNil(range2.sheetName)
        XCTAssertEqual(range2.startColumn?.value, "A")
        XCTAssertEqual(range2.startRow?.value, 1)
        XCTAssertNil(range2.endColumn)
        XCTAssertNil(range2.endRow)
        
        // Column only (open row) constraint not strictly enforced by parser, but struct structure:
        // "A:B" -> Parsed as Start(A) End(B) with rows nil
        let range3 = SheetRange(parsing: "A:B")
        XCTAssertEqual(range3.startColumn?.value, "A")
        XCTAssertNil(range3.startRow)
        XCTAssertEqual(range3.endColumn?.value, "B")
        XCTAssertNil(range3.endRow)
        
        // Sheet only? No, SheetRange expects range part usually or single part is parsed as cell.
        // "Sheet1!A1"
        let range4 = SheetRange(parsing: "Sheet1!A1")
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
        // Compiler guarantees: .from(col: Int) is impossible.
        // We verify runtime behavior of correct types.
        let c: SheetColumn = "X"
        let r: SheetRowIndex = 5
        let typed = SheetRange.root().from(col: c, row: r)
        XCTAssertEqual(typed.description, "X5")
    }
    
    // MARK: - Macro Tests
    
    func testRangeMacroUsage() {
        // This tests that the macro expands to a valid SheetRange object.
        // We cannot test compile-time failure here, but usage confirms macro functionality.
        let r = #Range("Sheet1!A1:B2")
        XCTAssertEqual(r.sheetName, "Sheet1")
        XCTAssertEqual(r.startColumn?.value, "A")
        XCTAssertEqual(r.endRow?.value, 2)
        
        let cell = #Range("Z99")
        XCTAssertEqual(cell.description, "Z99")
    }
}
