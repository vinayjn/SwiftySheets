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
        // Simple parser for "Sheet1!A1:B2" format
        // This is a basic implementation, can be improved with Regex
        let parts = value.components(separatedBy: "!")
        if parts.count == 2 {
            self.sheetName = parts[0]
            // Parse A1:B2 part...
            // For now, storing as raw string if needed or just minimal support
            // This init is for ExpressibleByStringLiteral, we might need to parse fully
             // TODO: robust parsing
             self.startColumn = nil; self.startRow = nil; self.endColumn = nil; self.endRow = nil
        } else {
             self.sheetName = nil; self.startColumn = nil; self.startRow = nil; self.endColumn = nil; self.endRow = nil
        }
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
