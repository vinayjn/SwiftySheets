/// Request models for Sheets API batch update operations.

// MARK: - Write Operation Request (Internal)

struct UpdateValuesRequest: Codable, Sendable {
    let range: String
    let majorDimension: String
    let values: [[String]]
    
    init(range: String, values: [[String]], majorDimension: String = "ROWS") {
        self.range = range
        self.values = values
        self.majorDimension = majorDimension
    }
}

// MARK: - Batch Update

/// The batch update request container. Users interact via DSL helpers like `AddSheet`, `DeleteSheet`.
public struct BatchUpdateRequest: Encodable, Sendable {
    let requests: [Request]
    
    /// Represents a single batch update operation.
    /// Users should use DSL helpers (`AddSheet`, `DeleteSheet`, `FormatCells`, etc.)
    /// rather than constructing these directly.
    public enum Request: Encodable, Sendable {
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
    
    init(requests: [Request]) {
        self.requests = requests
    }
}

// MARK: - Individual Requests
// These need to be public because they're associated values in a public enum,
// but users should use DSL helpers instead of constructing these directly.

public struct UpdateCellsRequest: Encodable, Sendable {
    let range: GridRange
    let rows: [RowData]
    let fields: String
    
    init(sheet: Sheet, range: SheetRange, rows: [RowData], fields: String = "*") {
        self.range = GridRange(sheetRange: range, sheetId: sheet.sheetId)
        self.rows = rows
        self.fields = fields
    }
}

public struct AddSheetRequest: Encodable, Sendable {
    let properties: Sheet.Draft
    
    init(properties: Sheet.Draft) {
        self.properties = properties
    }
}

public struct DeleteSheetRequest: Encodable, Sendable {
    let sheetId: Int
    
    init(sheetId: Int) {
        self.sheetId = sheetId
    }
}

public struct SortRangeRequest: Encodable, Sendable {
    let range: GridRange
    let sortSpecs: [SortSpec]
    
    init(sheet: Sheet, range: SheetRange, sortSpecs: [SortSpec]) {
        self.range = GridRange(sheetRange: range, sheetId: sheet.sheetId)
        self.sortSpecs = sortSpecs
    }
}

struct SortSpec: Encodable, Sendable {
    let dimensionIndex: Int
    let sortOrder: SortOrder
    
    init(dimensionIndex: Int, sortOrder: SortOrder) {
        self.dimensionIndex = dimensionIndex
        self.sortOrder = sortOrder
    }
}

public struct RepeatCellRequest: Encodable, Sendable {
    let range: GridRange
    let cell: CellData
    let fields: String
    
    init(sheet: Sheet, range: SheetRange, cell: CellData, fields: String) {
        self.range = GridRange(sheetRange: range, sheetId: sheet.sheetId)
        self.cell = cell
        self.fields = fields
    }
}

public struct UpdateSheetPropertiesRequest: Encodable, Sendable {
    let properties: Sheet.SheetProperties
    let fields: String
    
    init(properties: Sheet.SheetProperties, fields: String) {
        self.properties = properties
        self.fields = fields
    }
}

// MARK: - Cell Data (Internal)

struct RowData: Encodable, Sendable {
    let values: [CellData]
    
    init(values: [CellData]) {
        self.values = values
    }
}

// MARK: - Cell Value (Type Safe)

public enum CellValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case formula(String)
    case none
    
    enum CodingKeys: String, CodingKey {
        case stringValue
        case numberValue
        case boolValue
        case formulaValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let s): try container.encode(s, forKey: .stringValue)
        case .number(let n): try container.encode(n, forKey: .numberValue)
        case .bool(let b): try container.encode(b, forKey: .boolValue)
        case .formula(let f): try container.encode(f, forKey: .formulaValue)
        case .none: break
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? container.decode(String.self, forKey: .stringValue) {
            self = .string(s)
        } else if let n = try? container.decode(Double.self, forKey: .numberValue) {
            self = .number(n)
        } else if let b = try? container.decode(Bool.self, forKey: .boolValue) {
            self = .bool(b)
        } else if let f = try? container.decode(String.self, forKey: .formulaValue) {
            self = .formula(f)
        } else {
            self = .none
        }
    }
}

struct CellData: Encodable, Sendable {
    let userEnteredValue: CellValue?
    let userEnteredFormat: CellFormat?
    
    init(userEnteredValue: CellValue? = nil, userEnteredFormat: CellFormat? = nil) {
        self.userEnteredValue = userEnteredValue
        self.userEnteredFormat = userEnteredFormat
    }
}

// MARK: - Grid Range (Internal)

struct GridRange: Encodable, Sendable {
    let sheetId: Int?
    let startRowIndex: Int?
    let endRowIndex: Int?
    let startColumnIndex: Int?
    let endColumnIndex: Int?
    
    init(sheetId: Int? = nil, startRowIndex: Int? = nil, endRowIndex: Int? = nil, startColumnIndex: Int? = nil, endColumnIndex: Int? = nil) {
        self.sheetId = sheetId
        self.startRowIndex = startRowIndex
        self.endRowIndex = endRowIndex
        self.startColumnIndex = startColumnIndex
        self.endColumnIndex = endColumnIndex
    }
    
    init(range: String, sheetId: Int) throws {
        try self.init(sheetRange: SheetRange(parsing: range), sheetId: sheetId)
    }
    
    init(sheetRange: SheetRange, sheetId: Int) {
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
