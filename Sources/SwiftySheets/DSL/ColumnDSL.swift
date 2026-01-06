import Foundation

/// A reference to a specific column (e.g., "A", "Z", "AA").
public struct ColumnReference: Sendable, Hashable, Equatable, Comparable {
    /// 1-based index (A=1)
    public let index: Int
    
    public init(index: Int) {
        self.index = index
    }
    
    public static func < (lhs: ColumnReference, rhs: ColumnReference) -> Bool {
        lhs.index < rhs.index
    }
    
    /// Returns the A1 notation for this column (e.g. "AA")
    public var stringValue: String {
        SheetRange.indexToColumn(index - 1)
    }
    
    /// Create a cell location from this column and a row index.
    /// Usage: `Column.A[1]` -> "A1"
    public subscript(_ row: Int) -> SheetRange {
        guard row > 0 else { fatalError("Row index must be positive") }
        // Use internal unchecked inits since we validated row and column comes from enum
        return SheetRange.root().from(
            col: SheetColumn(unchecked: stringValue),
            row: SheetRowIndex(unchecked: row)
        )
    }
}

/// Namespace for column Autocomplete.
///
/// Use `Column.A`, `Column.Z` etc. for type-safe column references.
///
/// This enum is populated by the `@GenerateColumns` macro with static properties for columns A...ZZ.
@GenerateColumns
public enum Column {
    // Macro generates:
    // public static let A = ColumnReference(index: 1)
    // ...
    // public static let ZZ = ColumnReference(index: 702)
}

// MARK: - Range Builders

/// Enable `Column.A...Column.Z` to create a `SheetRange`.
public extension ColumnReference {
    static func ... (start: ColumnReference, end: ColumnReference) -> SheetRange {
        // Use unchecked because ColumnReference index is guaranteed valid (1...702)
        let sc = SheetColumn(unchecked: start.stringValue)
        let ec = SheetColumn(unchecked: end.stringValue)
        return SheetRange(startColumn: sc, endColumn: ec)
    }
}

public extension SheetRange {
    /// Create a range from two corner cells.
    /// Example: `Column.A[1]...Column.B[2]` -> "A1:B2"
    static func ... (start: SheetRange, end: SheetRange) -> SheetRange {
        // We assume start is top-left and end is bottom-right, or we normalize.
        // We merge them.
        // If start has sheetName but end does not, preserve sheetName.
        
        // This is simplified. Ideally we check if they share the same sheet.
        // Fallback to "A" and 1 if nil, to prevent crash, though logical range implies existence.
        let sCol = start.startColumn ?? SheetColumn(unchecked: "A")
        let sRow = start.startRow ?? SheetRowIndex(unchecked: 1)
        
        // For end range, we take its start properties as the corner
        let eCol = end.startColumn ?? SheetColumn(unchecked: "A")
        let eRow = end.startRow ?? SheetRowIndex(unchecked: 1)

        return SheetRange.root(start.sheetName)
            .from(col: sCol, row: sRow)
            .to(col: eCol, row: eRow)
    }
}
