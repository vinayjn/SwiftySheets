import Foundation

public struct SheetRange: Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let sheetName: String?
    public let startColumn: String?
    public let startRow: Int?
    public let endColumn: String?
    public let endRow: Int?
    
    public init(
        sheetName: String? = nil,
        startColumn: String? = nil,
        startRow: Int? = nil,
        endColumn: String? = nil,
        endRow: Int? = nil
    ) {
        self.sheetName = sheetName
        self.startColumn = startColumn
        self.startRow = startRow
        self.endColumn = endColumn
        self.endRow = endRow
    }
    
    public init(stringLiteral value: String) {
        // Format: Sheet1!A1:B2 or A1:B2 or Sheet1!A1
        let parts = value.components(separatedBy: "!")
        
        var rangePart = value
        if parts.count == 2 {
            self.sheetName = parts[0]
            rangePart = parts[1]
        } else {
            self.sheetName = nil
        }
        
        // Parse range: A1:B2
        let rangeParts = rangePart.components(separatedBy: ":")
        if rangeParts.count == 2 {
            // Start and End
            let start = Self.parseCell(rangeParts[0])
            let end = Self.parseCell(rangeParts[1])
            
            self.startColumn = start.col
            self.startRow = start.row
            self.endColumn = end.col
            self.endRow = end.row
        } else if rangeParts.count == 1 {
            // Just Start
            let start = Self.parseCell(rangeParts[0])
            self.startColumn = start.col
            self.startRow = start.row
            self.endColumn = nil
            self.endRow = nil
        } else {
            self.startColumn = nil; self.startRow = nil
            self.endColumn = nil; self.endRow = nil
        }
    }
    
    // Helper to convert "A" -> 0, "B" -> 1
    public static func columnToIndex(_ column: String) -> Int {
        var result = 0
        for char in column.unicodeScalars {
            result = result * 26 + Int(char.value) - Int(UnicodeScalar("A").value) + 1
        }
        return result - 1
    }

    
    public static func indexToColumn(_ index: Int) -> String {
        var i = index + 1
        var col = ""
        while i > 0 {
            let remainder = (i - 1) % 26
            col = String(UnicodeScalar(65 + remainder)!) + col
            i = (i - 1) / 26
        }
        return col
    }
    
    private static func parseCell(_ cell: String) -> (col: String?, row: Int?) {
        // Separate letters and numbers
        let letters = cell.filter { $0.isLetter }
        let numbers = cell.filter { $0.isNumber }
        
        let col = letters.isEmpty ? nil : String(letters)
        let row = Int(numbers)
        
        return (col, row)
    }
    
    public var description: String {
        var str = ""
        if let sheetName = sheetName {
            str += "\(sheetName)!"
        }
        if let startColumn = startColumn {
            str += startColumn
        }
        if let startRow = startRow {
            str += "\(startRow)"
        }
        if endColumn != nil || endRow != nil {
            str += ":"
        }
        if let endColumn = endColumn {
            str += endColumn
        }
        if let endRow = endRow {
            str += "\(endRow)"
        }
        return str
    }
}

// MARK: - Fluent Builder API

public extension SheetRange {
    static func root(_ sheet: String? = nil) -> SheetRange {
        SheetRange(sheetName: sheet)
    }
    
    func from(col: String? = nil, row: Int? = nil) -> SheetRange {
        var range = self
        if let c = col { range = SheetRange(sheetName: sheetName, startColumn: c, startRow: range.startRow, endColumn: range.endColumn, endRow: range.endRow) }
        if let r = row { range = SheetRange(sheetName: sheetName, startColumn: range.startColumn, startRow: r, endColumn: range.endColumn, endRow: range.endRow) }
        return range
    }
    
    func to(col: String? = nil, row: Int? = nil) -> SheetRange {
        var range = self
        // If start is missing, this acts as end?
        // Usually .from().to() implies start -> end.
        // We set end properties.
        return SheetRange(
            sheetName: sheetName,
            startColumn: startColumn,
            startRow: startRow,
            endColumn: col ?? endColumn,
            endRow: row ?? endRow
        )
    }
}
