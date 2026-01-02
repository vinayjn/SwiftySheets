public enum ValueInputOption: String {
    case raw = "RAW"
    case userEntered = "USER_ENTERED"
}

public enum ValueRenderOption: String {
    case formatted = "FORMATTED_VALUE"
    case unformatted = "UNFORMATTED_VALUE"
    case formula = "FORMULA"
}

public enum DateRenderOption: String {
    case serialNumber = "SERIAL_NUMBER"
    case formattedString = "FORMATTED_STRING"
}

struct ValueRange: Codable {
    let range: String
    let values: [[String]]
    
    enum CodingKeys: String, CodingKey {
        case range
        case values
    }
    
    init(range: String, values: [[String]]) {
        self.range = range
        self.values = values
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.range = try container.decode(String.self, forKey: .range)
        
        // Decode as [[SafeString]] to handle mixed types
        if let safeValues = try? container.decode([[SafeString]].self, forKey: .values) {
            self.values = safeValues.map { $0.map { $0.value } }
        } else {
            self.values = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range, forKey: .range)
        try container.encode(values, forKey: .values)
    }
}

// Helper to decode String, Int, Double, Bool into a String
private struct SafeString: Decodable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = String(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = String(boolValue)
        } else {
             // Fallback or throw? Let's use empty string or description if needed, strictly speaking if it's null it might end here.
             // If we really can't decode, let's treat it as empty or fallback.
             // Given Google sheets, usually keys are just these primitives.
             self.value = ""
        }
    }
}

public struct Sheet: Codable, Sendable {
    public let properties: SheetProperties

    public struct SheetProperties: Codable, Sendable {
        public let sheetId: Int
        public let title: String
        public let index: Int
        public let gridProperties: GridProperties

        enum CodingKeys: String, CodingKey {
            case sheetId
            case title
            case index
            case gridProperties
        }
        
        public init(sheetId: Int, title: String, index: Int, gridProperties: GridProperties) {
            self.sheetId = sheetId
            self.title = title
            self.index = index
            self.gridProperties = gridProperties
        }
    }

    public struct GridProperties: Codable, Sendable {
        public let rowCount: Int
        public let columnCount: Int
        
        public init(rowCount: Int, columnCount: Int) {
            self.rowCount = rowCount
            self.columnCount = columnCount
        }
    }
    
    public struct Draft: Encodable {
        public let title: String
        public let gridProperties: GridProperties?
        
        public init(title: String, gridProperties: GridProperties? = nil) {
            self.title = title
            self.gridProperties = gridProperties
        }
        
        // This ensures it encodes to "properties" key if nested,
        // but AddSheetRequest expects { properties: { title: ... } }
        // So Draft should look like SheetProperties when encoded but without ID.
    }
}

public extension Sheet {
    var title: String { properties.title }
    var sheetId: Int { properties.sheetId }
    var index: Int { properties.index }
    var rowCount: Int { properties.gridProperties.rowCount }
    var columnCount: Int { properties.gridProperties.columnCount }
}

// For Drive API responses
public struct DriveSearchResponse: Decodable {
    public let files: [DriveFile]

    public struct DriveFile: Decodable {
        public let id: String
        public let name: String
    }
}

// Write operation models
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

public struct UpdateValuesResponse: Codable {
    public let spreadsheetId: String
    public let updatedRange: String
    public let updatedRows: Int
    public let updatedColumns: Int
    public let updatedCells: Int
}

public struct AppendValuesResponse: Codable {
    public let spreadsheetId: String
    public let tableRange: String?
    public let updates: UpdateValuesResponse
}

public struct ClearValuesResponse: Codable {
    public let spreadsheetId: String
    public let clearedRange: String
}

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
    
    // Needed for init
    public init(requests: [Request]) {
        self.requests = requests
    }
}

public struct BatchUpdateResponse: Codable {
    public let spreadsheetId: String
    public let replies: [Reply]?
    
    public struct Reply: Codable {
        public let addSheet: AddSheetResponse?
        // Other replies can be added here
        
        // Make memberwise init if needed or rely on Codable synthesis for tests
        public init(addSheet: AddSheetResponse? = nil) {
            self.addSheet = addSheet
        }
    }
    
    public init(spreadsheetId: String, replies: [Reply]? = nil) {
        self.spreadsheetId = spreadsheetId
        self.replies = replies
    }
}

public struct UpdateCellsRequest: Codable {
    public let range: GridRange
    public let rows: [RowData]
    public let fields: String
    
    public init(range: GridRange, rows: [RowData], fields: String = "*") {
        self.range = range
        self.rows = rows
        self.fields = fields
    }
}

public struct AddSheetRequest: Encodable {
    public let properties: Sheet.Draft
    
    public init(properties: Sheet.Draft) {
        self.properties = properties
    }
    
    // Decoding support if needed (for responses), but AddSheetRequest is usually just sent.
    // The response is AddSheetResponse which contains 'properties' of type SheetProperties (with ID).
}

public struct AddSheetResponse: Codable {
    public let properties: Sheet.SheetProperties
    
    public init(properties: Sheet.SheetProperties) {
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
    
    public init(range: GridRange, sortSpecs: [SortSpec]) {
        self.range = range
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

public enum SortOrder: String, Codable {
    case ascending = "ASCENDING"
    case descending = "DESCENDING"
}

public struct RepeatCellRequest: Codable {
    public let range: GridRange
    public let cell: CellData
    public let fields: String
    
    public init(range: GridRange, cell: CellData, fields: String) {
        self.range = range
        self.cell = cell
        self.fields = fields
    }
}

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
}

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

public struct UpdateSheetPropertiesRequest: Codable {
    public let properties: Sheet.SheetProperties
    public let fields: String
    
    public init(properties: Sheet.SheetProperties, fields: String) {
        self.properties = properties
        self.fields = fields
    }
}
