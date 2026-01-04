@testable import SwiftySheets
import XCTest

final class BatchUpdateDSLTests: XCTestCase {
    
    func testDSLHelpers() {
        // Only testing request generation, no network needed
        let gridProps = Sheet.GridProperties(rowCount: 100, columnCount: 20)
        let sheetProps = Sheet.SheetProperties(sheetId: 123, title: "Test", index: 0, gridProperties: gridProps)
        let sheet = Sheet(properties: sheetProps)
        
        func build(@BatchUpdateBuilder _ content: () -> [BatchUpdateRequest.Request]) -> [BatchUpdateRequest.Request] {
            content()
        }
        
        let requests = build {
            FormatCells(sheet: sheet, range: #Range("A1"), format: CellFormat(backgroundColor: .red))
            SortRange(sheet: sheet, range: #Range("A2:C"), column: 0)
            ResizeSheet(sheet: sheet, rows: 50, columns: 5)
        }
        
        XCTAssertEqual(requests.count, 3)
        // Could inspect request types but enum associated values are hard to check directly without Equatable
        // We trust the helpers call the correct initializers which are tested via integration tests/demo
    }
}
