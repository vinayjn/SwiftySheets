@testable import SwiftySheets
import XCTest

final class CellFormatBuilderTests: XCTestCase {
    
    // MARK: - Individual Format Properties
    
    func testBackgroundColor() {
        let format = CellFormatBuilder.buildBlock(BackgroundColor(.red))
        
        XCTAssertNotNil(format.backgroundColor)
        XCTAssertEqual(format.backgroundColor?.red, 1.0)
        XCTAssertEqual(format.backgroundColor?.green, 0.0)
        XCTAssertEqual(format.backgroundColor?.blue, 0.0)
    }
    
    func testBold() {
        let format = CellFormatBuilder.buildBlock(Bold())
        
        XCTAssertNotNil(format.textFormat)
        XCTAssertEqual(format.textFormat?.bold, true)
    }
    
    func testBoldDisabled() {
        let format = CellFormatBuilder.buildBlock(Bold(false))
        
        XCTAssertEqual(format.textFormat?.bold, false)
    }
    
    func testItalic() {
        let format = CellFormatBuilder.buildBlock(Italic())
        
        XCTAssertEqual(format.textFormat?.italic, true)
    }
    
    func testUnderline() {
        let format = CellFormatBuilder.buildBlock(Underline())
        
        XCTAssertEqual(format.textFormat?.underline, true)
    }
    
    func testStrikethrough() {
        let format = CellFormatBuilder.buildBlock(Strikethrough())
        
        XCTAssertEqual(format.textFormat?.strikethrough, true)
    }
    
    func testFontSize() {
        let format = CellFormatBuilder.buildBlock(FontSize(14))
        
        XCTAssertEqual(format.textFormat?.fontSize, 14)
    }
    
    func testFontFamily() {
        let format = CellFormatBuilder.buildBlock(FontFamily("Arial"))
        
        XCTAssertEqual(format.textFormat?.fontFamily, "Arial")
    }
    
    func testForegroundColor() {
        let format = CellFormatBuilder.buildBlock(ForegroundColor(.blue))
        
        XCTAssertNotNil(format.textFormat?.foregroundColor)
        XCTAssertEqual(format.textFormat?.foregroundColor?.blue, 1.0)
    }
    
    func testAlignment() {
        let formatCenter = CellFormatBuilder.buildBlock(Alignment(.center))
        XCTAssertEqual(formatCenter.horizontalAlignment, .center)
        
        let formatLeft = CellFormatBuilder.buildBlock(Alignment.left)
        XCTAssertEqual(formatLeft.horizontalAlignment, .left)
        
        let formatRight = CellFormatBuilder.buildBlock(Alignment.right)
        XCTAssertEqual(formatRight.horizontalAlignment, .right)
    }
    
    // MARK: - Combined Properties
    
    func testMultipleProperties() {
        let format = CellFormatBuilder.buildBlock(
            BackgroundColor(.blue),
            Bold(),
            FontSize(16),
            Alignment(.center)
        )
        
        XCTAssertNotNil(format.backgroundColor)
        XCTAssertEqual(format.backgroundColor?.blue, 1.0)
        XCTAssertEqual(format.textFormat?.bold, true)
        XCTAssertEqual(format.textFormat?.fontSize, 16)
        XCTAssertEqual(format.horizontalAlignment, .center)
    }
    
    func testAllTextFormatProperties() {
        let format = CellFormatBuilder.buildBlock(
            Bold(),
            Italic(),
            Underline(),
            Strikethrough(),
            FontSize(12),
            FontFamily("Roboto"),
            ForegroundColor(.green)
        )
        
        XCTAssertEqual(format.textFormat?.bold, true)
        XCTAssertEqual(format.textFormat?.italic, true)
        XCTAssertEqual(format.textFormat?.underline, true)
        XCTAssertEqual(format.textFormat?.strikethrough, true)
        XCTAssertEqual(format.textFormat?.fontSize, 12)
        XCTAssertEqual(format.textFormat?.fontFamily, "Roboto")
        XCTAssertEqual(format.textFormat?.foregroundColor?.green, 1.0)
    }
    
    // MARK: - Custom Colors
    
    func testCustomBackgroundColor() {
        let format = CellFormatBuilder.buildBlock(
            BackgroundColor(red: 0.5, green: 0.5, blue: 0.5)
        )
        
        XCTAssertEqual(format.backgroundColor?.red, 0.5)
        XCTAssertEqual(format.backgroundColor?.green, 0.5)
        XCTAssertEqual(format.backgroundColor?.blue, 0.5)
    }
    
    // MARK: - Empty Format
    
    func testEmptyFormat() {
        let format = CellFormatBuilder.buildBlock()
        
        XCTAssertNil(format.backgroundColor)
        XCTAssertNil(format.textFormat)
        XCTAssertNil(format.horizontalAlignment)
    }
}
