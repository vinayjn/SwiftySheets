import Foundation

public struct SheetRange: Sendable, CustomStringConvertible {
    public let sheetName: String?
    public let startColumn: SheetColumn?
    public let startRow: SheetRowIndex?
    public let endColumn: SheetColumn?
    public let endRow: SheetRowIndex?
    
    public init(
        sheetName: String? = nil,
        startColumn: SheetColumn? = nil,
        startRow: SheetRowIndex? = nil,
        endColumn: SheetColumn? = nil,
        endRow: SheetRowIndex? = nil
    ) {
        self.sheetName = sheetName
        self.startColumn = startColumn
        self.startRow = startRow
        self.endColumn = endColumn
        self.endRow = endRow
    }
    
    /// Parse a range string at runtime (e.g. "Sheet1!A1:B2").
    /// Use this for dynamic content. For static content, use `#Range("...")`.
    /// Throws if the format is invalid.
    public init(parsing value: String) throws {
        // Format: Sheet1!A1:B2 or A1:B2 or Sheet1!A1
        let parts = value.components(separatedBy: "!")
        
        var rangePart = value
        if parts.count == 2 {
            // Strip surrounding single-quotes from sheet names (e.g. 'My Sheet' → My Sheet)
            self.sheetName = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            rangePart = parts[1]
        } else {
            self.sheetName = nil
        }
        
        // Parse range: A1:B2
        let rangeParts = rangePart.components(separatedBy: ":")
        if rangeParts.count == 2 {
            let start = try Self.parseCell(rangeParts[0])
            let end = try Self.parseCell(rangeParts[1])
            
            self.startColumn = start.col
            self.startRow = start.row
            self.endColumn = end.col
            self.endRow = end.row
        } else if rangeParts.count == 1 {
            let start = try Self.parseCell(rangeParts[0])
            self.startColumn = start.col
            self.startRow = start.row
            self.endColumn = nil
            self.endRow = nil
        } else {
            throw SheetsError.invalidRange(message: "Invalid range format: '\(value)'")
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
    
    private static func parseCell(_ cell: String) throws -> (col: SheetColumn?, row: SheetRowIndex?) {
        let letters = cell.filter { $0.isLetter }
        let numbers = cell.filter { $0.isNumber }
        
        let col: SheetColumn?
        if !letters.isEmpty {
            col = try SheetColumn(String(letters))
        } else {
            col = nil
        }
        
        let row: SheetRowIndex?
        if let n = Int(numbers), n > 0 {
            row = try SheetRowIndex(n)
        } else if !numbers.isEmpty {
            throw SheetsError.invalidRange(message: "Invalid row number: '\(numbers)'")
        } else {
            row = nil
        }
        
        return (col, row)
    }
    
    public var description: String {
        var str = ""
        if let sheetName = sheetName {
            str += "\(sheetName)!"
        }
        if let startColumn = startColumn {
            str += startColumn.description
        }
        if let startRow = startRow {
            str += startRow.description
        }
        if endColumn != nil || endRow != nil {
            str += ":"
        }
        if let endColumn = endColumn {
            str += endColumn.description
        }
        if let endRow = endRow {
            str += endRow.description
        }
        return str
    }
}

// MARK: - Fluent Builder API

public extension SheetRange {
    static func root(_ sheet: String? = nil) -> SheetRange {
        SheetRange(sheetName: sheet)
    }
    
    func from(col: SheetColumn? = nil, row: SheetRowIndex? = nil) -> SheetRange {
        var range = self
        if let c = col { 
            range = range.with(startColumn: c)
        }
        if let r = row { 
            range = range.with(startRow: r)
        }
        return range
    }
    
    func to(col: SheetColumn? = nil, row: SheetRowIndex? = nil) -> SheetRange {
        var r = self
        if let c = col { r = r.with(endColumn: c) }
        if let rw = row { r = r.with(endRow: rw) }
        return r
    }
}

// Internal immutable setters
internal extension SheetRange {
    func with(startColumn: SheetColumn? = nil, startRow: SheetRowIndex? = nil, endColumn: SheetColumn? = nil, endRow: SheetRowIndex? = nil) -> SheetRange {
        SheetRange(
            sheetName: self.sheetName,
            startColumn: startColumn ?? self.startColumn,
            startRow: startRow ?? self.startRow,
            endColumn: endColumn ?? self.endColumn,
            endRow: endRow ?? self.endRow
        )
    }
}
