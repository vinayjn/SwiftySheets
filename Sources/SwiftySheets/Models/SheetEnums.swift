/// Sheet-related enums for value handling and rendering options.

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

public enum SortOrder: String, Codable {
    case ascending = "ASCENDING"
    case descending = "DESCENDING"
}
