import Foundation

public struct Color: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public static let black = Color(red: 0, green: 0, blue: 0)
    public static let white = Color(red: 1, green: 1, blue: 1)
    public static let red = Color(red: 1, green: 0, blue: 0)
    public static let green = Color(red: 0, green: 1, blue: 0)
    public static let blue = Color(red: 0, green: 0, blue: 1)
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)
}

public enum HorizontalAlignment: String, Codable, Sendable {
    case left = "LEFT"
    case center = "CENTER"
    case right = "RIGHT"
}

public struct TextFormat: Codable, Equatable, Sendable {
    public var foregroundColor: Color?
    public var fontFamily: String?
    public var fontSize: Int?
    public var bold: Bool?
    public var italic: Bool?
    public var strikethrough: Bool?
    public var underline: Bool?
    
    public init(
        foregroundColor: Color? = nil,
        fontFamily: String? = nil,
        fontSize: Int? = nil,
        bold: Bool? = nil,
        italic: Bool? = nil,
        strikethrough: Bool? = nil,
        underline: Bool? = nil
    ) {
        self.foregroundColor = foregroundColor
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.bold = bold
        self.italic = italic
        self.strikethrough = strikethrough
        self.underline = underline
    }
}

public struct CellFormat: Codable, Equatable, Sendable {
    public var backgroundColor: Color?
    public var horizontalAlignment: HorizontalAlignment?
    public var textFormat: TextFormat?
    
    public init(
        backgroundColor: Color? = nil,
        horizontalAlignment: HorizontalAlignment? = nil,
        textFormat: TextFormat? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.horizontalAlignment = horizontalAlignment
        self.textFormat = textFormat
    }
}
