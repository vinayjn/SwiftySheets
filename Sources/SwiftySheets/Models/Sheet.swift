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

struct ValueRange: Decodable {
    let range: String
    let values: [[String]]
}

public struct Sheet: Decodable {
    public let properties: SheetProperties

    public struct SheetProperties: Decodable {
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
    }

    public struct GridProperties: Decodable {
        public let rowCount: Int
        public let columnCount: Int
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
