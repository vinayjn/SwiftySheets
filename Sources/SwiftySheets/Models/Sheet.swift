/// Core Sheet model and related types.

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
    }
}

public extension Sheet {
    var title: String { properties.title }
    var sheetId: Int { properties.sheetId }
    var index: Int { properties.index }
    var rowCount: Int { properties.gridProperties.rowCount }
    var columnCount: Int { properties.gridProperties.columnCount }
}
