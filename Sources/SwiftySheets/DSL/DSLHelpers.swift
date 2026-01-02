import Foundation

// These helpers create Request objects easily

public func AddSheet(_ title: String, gridProperties: Sheet.GridProperties? = nil) -> BatchUpdateRequest.Request {
    .addSheet(AddSheetRequest(properties: Sheet.Draft(title: title, gridProperties: gridProperties ?? Sheet.GridProperties(rowCount: 1000, columnCount: 26))))
}

public func DeleteSheet(id: Int) -> BatchUpdateRequest.Request {
    .deleteSheet(DeleteSheetRequest(sheetId: id))
}

// More helpers can be added for UpdateCells etc.
