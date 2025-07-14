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
}

public struct Sheet: Decodable {
    public let properties: SheetProperties

    public struct SheetProperties: Codable {
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

    public struct GridProperties: Codable {
        public let rowCount: Int
        public let columnCount: Int
        
        public init(rowCount: Int, columnCount: Int) {
            self.rowCount = rowCount
            self.columnCount = columnCount
        }
    }
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

public struct BatchUpdateRequest: Codable {
    public let requests: [Request]
    
    public enum Request: Codable {
        case updateCells(UpdateCellsRequest)
        case addSheet(AddSheetRequest)
        case deleteSheet(DeleteSheetRequest)
        
        enum CodingKeys: String, CodingKey {
            case updateCells
            case addSheet
            case deleteSheet
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
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let updateCells = try? container.decode(UpdateCellsRequest.self, forKey: .updateCells) {
                self = .updateCells(updateCells)
            } else if let addSheet = try? container.decode(AddSheetRequest.self, forKey: .addSheet) {
                self = .addSheet(addSheet)
            } else if let deleteSheet = try? container.decode(DeleteSheetRequest.self, forKey: .deleteSheet) {
                self = .deleteSheet(deleteSheet)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown request type"))
            }
        }
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

public struct AddSheetRequest: Codable {
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
    
    public init(userEnteredValue: ExtendedValue?) {
        self.userEnteredValue = userEnteredValue
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
