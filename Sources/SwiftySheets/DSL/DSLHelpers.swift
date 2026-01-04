import Foundation

// These helpers create Request objects easily

public func AddSheet(_ title: String, gridProperties: Sheet.GridProperties? = nil) -> BatchUpdateRequest.Request {
    .addSheet(AddSheetRequest(properties: Sheet.Draft(title: title, gridProperties: gridProperties ?? Sheet.GridProperties(rowCount: 1000, columnCount: 26))))
}

public func DeleteSheet(id: Int) -> BatchUpdateRequest.Request {
    .deleteSheet(DeleteSheetRequest(sheetId: id))
}

// More helpers can be added for UpdateCells etc.

public func FormatCells(sheet: Sheet, range: SheetRange, format: CellFormat) -> BatchUpdateRequest.Request {
    let gridRange = GridRange(sheetRange: range, sheetId: sheet.sheetId)
    let cellData = CellData(userEnteredFormat: format)
    return .repeatCell(RepeatCellRequest(range: gridRange, cell: cellData, fields: "userEnteredFormat"))
}

public func SortRange(sheet: Sheet, range: SheetRange, column: Int, ascending: Bool = true) -> BatchUpdateRequest.Request {
    let gridRange = GridRange(sheetRange: range, sheetId: sheet.sheetId)
    let sortSpec = SortSpec(
        dimensionIndex: column,
        sortOrder: ascending ? .ascending : .descending
    )
    return .sortRange(SortRangeRequest(range: gridRange, sortSpecs: [sortSpec]))
}

public func ResizeSheet(sheet: Sheet, rows: Int, columns: Int) -> BatchUpdateRequest.Request {
    let gridProps = Sheet.GridProperties(rowCount: rows, columnCount: columns)
    let props = Sheet.SheetProperties(
        sheetId: sheet.sheetId,
        title: "", // Ignored by fields mask
        index: 0, // Ignored
        gridProperties: gridProps
    )
    return .updateSheetProperties(UpdateSheetPropertiesRequest(properties: props, fields: "gridProperties"))
}
