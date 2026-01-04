import Foundation

public protocol BatchRequestConvertible {
    var request: BatchUpdateRequest.Request { get }
}

// Conform the raw Request enum to the protocol so it can be used directly
extension BatchUpdateRequest.Request: BatchRequestConvertible {
    public var request: BatchUpdateRequest.Request { self }
}

public struct AddSheet: BatchRequestConvertible {
    let title: String
    let gridProperties: Sheet.GridProperties?
    
    public init(_ title: String, gridProperties: Sheet.GridProperties? = nil) {
        self.title = title
        self.gridProperties = gridProperties
    }
    
    public var request: BatchUpdateRequest.Request {
        .addSheet(AddSheetRequest(properties: Sheet.Draft(title: title, gridProperties: gridProperties ?? Sheet.GridProperties(rowCount: 1000, columnCount: 26))))
    }
}

public struct DeleteSheet: BatchRequestConvertible {
    let id: Int
    
    public init(id: Int) {
        self.id = id
    }
    
    public var request: BatchUpdateRequest.Request {
        .deleteSheet(DeleteSheetRequest(sheetId: id))
    }
}

public struct FormatCells: BatchRequestConvertible {
    let sheet: Sheet
    let range: SheetRange
    let format: CellFormat
    
    public init(sheet: Sheet, range: SheetRange, format: CellFormat) {
        self.sheet = sheet
        self.range = range
        self.format = format
    }
    
    public var request: BatchUpdateRequest.Request {
        .repeatCell(RepeatCellRequest(sheet: sheet, range: range, cell: CellData(userEnteredFormat: format), fields: "userEnteredFormat"))
    }
}

public struct SortRange: BatchRequestConvertible {
    let sheet: Sheet
    let range: SheetRange
    let column: Int
    let ascending: Bool
    
    public init(sheet: Sheet, range: SheetRange, column: Int, ascending: Bool = true) {
        self.sheet = sheet
        self.range = range
        self.column = column
        self.ascending = ascending
    }
    
    public var request: BatchUpdateRequest.Request {
        let sortSpec = SortSpec(
            dimensionIndex: column,
            sortOrder: ascending ? .ascending : .descending
        )
        return .sortRange(SortRangeRequest(sheet: sheet, range: range, sortSpecs: [sortSpec]))
    }
}

public struct ResizeSheet: BatchRequestConvertible {
    let sheet: Sheet
    let rows: Int
    let columns: Int
    
    public init(sheet: Sheet, rows: Int, columns: Int) {
        self.sheet = sheet
        self.rows = rows
        self.columns = columns
    }
    
    public var request: BatchUpdateRequest.Request {
        let gridProps = Sheet.GridProperties(rowCount: rows, columnCount: columns)
        let props = Sheet.SheetProperties(
            sheetId: sheet.sheetId,
            title: "",
            index: 0,
            gridProperties: gridProps
        )
        return .updateSheetProperties(UpdateSheetPropertiesRequest(properties: props, fields: "gridProperties"))
    }
}
