/// Request models for Sheets API batch update operations.

// MARK: - Write Operation Request

public struct UpdateValuesRequest: Codable {
    public let range: String
    public let majorDimension: String
    public let values: [[String]]
    
    public init(range: String, values: [[String]], majorDimension: String = "ROWS") {
        self.range = range
        self.values = values
        self.majorDimension = majorDimension
    }
}

// MARK: - Batch Update

public struct BatchUpdateRequest: Encodable {
    public let requests: [Request]
    
    public enum Request: Encodable {
        case updateCells(UpdateCellsRequest)
        case addSheet(AddSheetRequest)
        case deleteSheet(DeleteSheetRequest)
        case repeatCell(RepeatCellRequest)
        case sortRange(SortRangeRequest)
        case updateSheetProperties(UpdateSheetPropertiesRequest)
        
        enum CodingKeys: String, CodingKey {
            case updateCells
            case addSheet
            case deleteSheet
            case repeatCell
            case sortRange
            case updateSheetProperties
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .updateCells(let request):
                try container.encode(request, forKey: .updateCells)
            case .addSheet(let request):
                try container.encode(request, forKey: .addSheet)
            case .deleteSheet(let request):
                try container.encode(request, forKey: .deleteSheet)
            case .repeatCell(let request):
                try container.encode(request, forKey: .repeatCell)
            case .sortRange(let request):
                try container.encode(request, forKey: .sortRange)
            case .updateSheetProperties(let request):
                try container.encode(request, forKey: .updateSheetProperties)
            }
        }
    }
    
    public init(requests: [Request]) {
        self.requests = requests
    }
}

// MARK: - Individual Requests

public struct UpdateCellsRequest: Codable {
    public let range: GridRange
    public let rows: [RowData]
    public let fields: String
    
    public init(sheet: Sheet, range: SheetRange, rows: [RowData], fields: String = "*") {
        self.range = GridRange(sheetRange: range, sheetId: sheet.sheetId)
        self.rows = rows
        self.fields = fields
    }
}

public struct AddSheetRequest: Encodable {
    public let properties: Sheet.Draft
    
    public init(properties: Sheet.Draft) {
        self.properties = properties
    }
}

public struct DeleteSheetRequest: Codable {
    public let sheetId: Int
    
    public init(sheetId: Int) {
        self.sheetId = sheetId
    }
}

public struct SortRangeRequest: Codable {
    public let range: GridRange
    public let sortSpecs: [SortSpec]
    
    public init(sheet: Sheet, range: SheetRange, sortSpecs: [SortSpec]) {
        self.range = GridRange(sheetRange: range, sheetId: sheet.sheetId)
        self.sortSpecs = sortSpecs
    }
}

public struct SortSpec: Codable {
    public let dimensionIndex: Int
    public let sortOrder: SortOrder
    
    public init(dimensionIndex: Int, sortOrder: SortOrder) {
        self.dimensionIndex = dimensionIndex
        self.sortOrder = sortOrder
    }
}

public struct RepeatCellRequest: Codable {
    public let range: GridRange
    public let cell: CellData
    public let fields: String
    
    public init(sheet: Sheet, range: SheetRange, cell: CellData, fields: String) {
        self.range = GridRange(sheetRange: range, sheetId: sheet.sheetId)
        self.cell = cell
        self.fields = fields
    }
}

public struct UpdateSheetPropertiesRequest: Codable {
    public let properties: Sheet.SheetProperties
    public let fields: String
    
    public init(properties: Sheet.SheetProperties, fields: String) {
        self.properties = properties
        self.fields = fields
    }
}

// MARK: - Cell Data

public struct RowData: Codable {
    public let values: [CellData]
    
    public init(values: [CellData]) {
        self.values = values
    }
}

public struct CellData: Codable {
    public let userEnteredValue: ExtendedValue?
    public let userEnteredFormat: CellFormat?
    
    public init(userEnteredValue: ExtendedValue? = nil, userEnteredFormat: CellFormat? = nil) {
        self.userEnteredValue = userEnteredValue
        self.userEnteredFormat = userEnteredFormat
    }
}

public struct ExtendedValue: Codable {
    public let stringValue: String?
    public let numberValue: Double?
    public let boolValue: Bool?
    
    public init(stringValue: String? = nil, numberValue: Double? = nil, boolValue: Bool? = nil) {
        self.stringValue = stringValue
        self.numberValue = numberValue
        self.boolValue = boolValue
    }
}

// MARK: - Grid Range

public struct GridRange: Codable {
    public let sheetId: Int?
    public let startRowIndex: Int?
    public let endRowIndex: Int?
    public let startColumnIndex: Int?
    public let endColumnIndex: Int?
    
    public init(sheetId: Int? = nil, startRowIndex: Int? = nil, endRowIndex: Int? = nil, startColumnIndex: Int? = nil, endColumnIndex: Int? = nil) {
        self.sheetId = sheetId
        self.startRowIndex = startRowIndex
        self.endRowIndex = endRowIndex
        self.startColumnIndex = startColumnIndex
        self.endColumnIndex = endColumnIndex
    }
    
    internal init(range: String, sheetId: Int) {
        self.init(sheetRange: SheetRange(parsing: range), sheetId: sheetId)
    }
    
    public init(sheetRange: SheetRange, sheetId: Int) {
        let startRowIndex = sheetRange.startRow.map { $0.value - 1 }
        
        var endRowIndex: Int? = sheetRange.endRow?.value
        if endRowIndex == nil, let start = startRowIndex {
            if sheetRange.endColumn == nil {
                endRowIndex = start + 1
            }
        }
        
        let startColumnIndex = sheetRange.startColumn.map { SheetRange.columnToIndex($0.value) }
        
        var endColumnIndex: Int?
        if let endColStr = sheetRange.endColumn {
            endColumnIndex = SheetRange.columnToIndex(endColStr.value) + 1
        } else if let start = startColumnIndex {
            endColumnIndex = start + 1
        }
        
        self.init(
            sheetId: sheetId,
            startRowIndex: startRowIndex,
            endRowIndex: endRowIndex,
            startColumnIndex: startColumnIndex,
            endColumnIndex: endColumnIndex
        )
    }
}
