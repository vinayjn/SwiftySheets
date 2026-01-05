/// Response models for Sheets API operations.

struct ValueRange: Codable, Sendable {
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
private struct SafeString: Decodable, Sendable {
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
            self.value = ""
        }
    }
}

public struct UpdateValuesResponse: Codable, Sendable {
    public let spreadsheetId: String
    public let updatedRange: String
    public let updatedRows: Int
    public let updatedColumns: Int
    public let updatedCells: Int
}

public struct AppendValuesResponse: Codable, Sendable {
    public let spreadsheetId: String
    public let tableRange: String?
    public let updates: UpdateValuesResponse
}

public struct ClearValuesResponse: Codable, Sendable {
    public let spreadsheetId: String
    public let clearedRange: String
}

public struct BatchUpdateResponse: Codable, Sendable {
    public let spreadsheetId: String
    public let replies: [Reply]?
    
    public struct Reply: Codable, Sendable {
        public let addSheet: AddSheetResponse?
        
        public init(addSheet: AddSheetResponse? = nil) {
            self.addSheet = addSheet
        }
    }
    
    public init(spreadsheetId: String, replies: [Reply]? = nil) {
        self.spreadsheetId = spreadsheetId
        self.replies = replies
    }
}

public struct AddSheetResponse: Codable, Sendable {
    public let properties: Sheet.SheetProperties
    
    public init(properties: Sheet.SheetProperties) {
        self.properties = properties
    }
}
