@testable import SwiftySheets
import XCTest

final class UtilityTests: XCTestCase {
    
    // MARK: - Column Index Conversion
    
    func testColumnToIndex() {
        // Single letters
        XCTAssertEqual(SheetRange.columnToIndex("A"), 0)
        XCTAssertEqual(SheetRange.columnToIndex("B"), 1)
        XCTAssertEqual(SheetRange.columnToIndex("Z"), 25)
        
        // Double letters
        XCTAssertEqual(SheetRange.columnToIndex("AA"), 26)
        XCTAssertEqual(SheetRange.columnToIndex("AB"), 27)
        XCTAssertEqual(SheetRange.columnToIndex("AZ"), 51)
        XCTAssertEqual(SheetRange.columnToIndex("BA"), 52)
        XCTAssertEqual(SheetRange.columnToIndex("ZZ"), 701)
        
        // Triple letters
        XCTAssertEqual(SheetRange.columnToIndex("AAA"), 702)
    }
    
    func testIndexToColumn() {
        // Single letters
        XCTAssertEqual(SheetRange.indexToColumn(0), "A")
        XCTAssertEqual(SheetRange.indexToColumn(1), "B")
        XCTAssertEqual(SheetRange.indexToColumn(25), "Z")
        
        // Double letters
        XCTAssertEqual(SheetRange.indexToColumn(26), "AA")
        XCTAssertEqual(SheetRange.indexToColumn(27), "AB")
        XCTAssertEqual(SheetRange.indexToColumn(51), "AZ")
        XCTAssertEqual(SheetRange.indexToColumn(52), "BA")
        XCTAssertEqual(SheetRange.indexToColumn(701), "ZZ")
        
        // Triple letters
        XCTAssertEqual(SheetRange.indexToColumn(702), "AAA")
    }
    
    func testColumnIndexRoundTrip() {
        // Round-trip: index -> column -> index
        for i in 0..<1000 {
            let column = SheetRange.indexToColumn(i)
            let backToIndex = SheetRange.columnToIndex(column)
            XCTAssertEqual(backToIndex, i, "Round trip failed for index \(i)")
        }
    }
    
    // MARK: - Formatting Types
    
    func testColorCodable() throws {
        let color = Color(red: 0.25, green: 0.5, blue: 0.75, alpha: 1.0)
        let data = try JSONEncoder().encode(color)
        let decoded = try JSONDecoder().decode(Color.self, from: data)
        
        XCTAssertEqual(decoded, color)
    }
    
    func testTextFormatCodable() throws {
        let format = TextFormat(
            foregroundColor: Color(red: 1.0, green: 0, blue: 0),
            fontFamily: "Arial",
            fontSize: 12,
            bold: true,
            italic: false
        )
        
        let data = try JSONEncoder().encode(format)
        let decoded = try JSONDecoder().decode(TextFormat.self, from: data)
        
        XCTAssertEqual(decoded.bold, true)
        XCTAssertEqual(decoded.fontFamily, "Arial")
    }
    
    func testCellFormatCodable() throws {
        let format = CellFormat(
            backgroundColor: Color(red: 0, green: 0, blue: 1),
            horizontalAlignment: .center,
            textFormat: TextFormat(bold: true)
        )
        
        let data = try JSONEncoder().encode(format)
        let json = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(json.contains("CENTER"))
        
        let decoded = try JSONDecoder().decode(CellFormat.self, from: data)
        XCTAssertEqual(decoded.horizontalAlignment, .center)
        XCTAssertEqual(decoded.textFormat?.bold, true)
    }
    
    // MARK: - DriveQuery Combinators
    
    func testDriveQuerySpreadsheets() {
        let query = DriveQuery.spreadsheets
        XCTAssertTrue(query.query.contains("application/vnd.google-apps.spreadsheet"))
    }
    
    func testDriveQueryFolders() {
        let query = DriveQuery.folders
        XCTAssertTrue(query.query.contains("application/vnd.google-apps.folder"))
    }
    
    func testDriveQueryNotTrashed() {
        let query = DriveQuery.notTrashed
        XCTAssertEqual(query.query, "trashed = false")
    }
    
    func testDriveQueryNameContains() {
        let query = DriveQuery.nameContains("Budget")
        XCTAssertTrue(query.query.contains("Budget"))
        XCTAssertTrue(query.query.contains("name contains"))
    }
    
    func testDriveQueryCombination() {
        let query = DriveQuery.spreadsheets.and(.notTrashed)
        
        XCTAssertTrue(query.query.contains("mimeType"))
        XCTAssertTrue(query.query.contains("trashed = false"))
        XCTAssertTrue(query.query.contains(") and ("))
    }
    
    func testDriveQueryMultipleCombinations() {
        let query = DriveQuery.spreadsheets
            .and(.notTrashed)
            .and(.nameContains("2024"))
        
        XCTAssertTrue(query.query.contains("mimeType"))
        XCTAssertTrue(query.query.contains("trashed"))
        XCTAssertTrue(query.query.contains("2024"))
    }
}
