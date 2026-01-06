/// Sheet-related enums for value handling and rendering options.

public enum ValueInputOption: String, Sendable {
    case raw = "RAW"
    case userEntered = "USER_ENTERED"
}

public enum ValueRenderOption: String, Sendable {
    case formatted = "FORMATTED_VALUE"
    case unformatted = "UNFORMATTED_VALUE"
    case formula = "FORMULA"
}

public enum DateRenderOption: String, Sendable {
    case serialNumber = "SERIAL_NUMBER"
    case formattedString = "FORMATTED_STRING"
}

public enum SortOrder: String, Codable, Sendable {
    case ascending = "ASCENDING"
    case descending = "DESCENDING"
}

public enum SortDimension: String, Codable, Sendable {
    case rows = "ROWS"
    case columns = "COLUMNS"
}
