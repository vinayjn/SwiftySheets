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

// MARK: - Fluent API

public extension CellFormat {
    // MARK: Static Entry Points
    
    /// Create a format with a background color.
    static func backgroundColor(_ color: Color) -> CellFormat {
        CellFormat(backgroundColor: color)
    }
    
    /// Create a format with horizontal alignment.
    static func alignment(_ alignment: HorizontalAlignment) -> CellFormat {
        CellFormat(horizontalAlignment: alignment)
    }
    
    /// Create a format with bold text.
    static func bold(_ enabled: Bool = true) -> CellFormat {
        CellFormat(textFormat: TextFormat(bold: enabled))
    }
    
    /// Create a format with italic text.
    static func italic(_ enabled: Bool = true) -> CellFormat {
        CellFormat(textFormat: TextFormat(italic: enabled))
    }
    
    /// Create a format with underlined text.
    static func underline(_ enabled: Bool = true) -> CellFormat {
        CellFormat(textFormat: TextFormat(underline: enabled))
    }
    
    /// Create a format with strikethrough text.
    static func strikethrough(_ enabled: Bool = true) -> CellFormat {
        CellFormat(textFormat: TextFormat(strikethrough: enabled))
    }
    
    /// Create a format with a specific font size.
    static func fontSize(_ size: Int) -> CellFormat {
        CellFormat(textFormat: TextFormat(fontSize: size))
    }
    
    /// Create a format with a specific font family.
    static func fontFamily(_ family: String) -> CellFormat {
        CellFormat(textFormat: TextFormat(fontFamily: family))
    }
    
    /// Create a format with a foreground (text) color.
    static func foregroundColor(_ color: Color) -> CellFormat {
        CellFormat(textFormat: TextFormat(foregroundColor: color))
    }
    
    // MARK: Chaining Methods
    
    /// Add a background color to this format.
    func backgroundColor(_ color: Color) -> CellFormat {
        var copy = self
        copy.backgroundColor = color
        return copy
    }
    
    /// Add horizontal alignment to this format.
    func alignment(_ alignment: HorizontalAlignment) -> CellFormat {
        var copy = self
        copy.horizontalAlignment = alignment
        return copy
    }
    
    /// Add bold styling to this format.
    func bold(_ enabled: Bool = true) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.bold = enabled
        return copy
    }
    
    /// Add italic styling to this format.
    func italic(_ enabled: Bool = true) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.italic = enabled
        return copy
    }
    
    /// Add underline styling to this format.
    func underline(_ enabled: Bool = true) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.underline = enabled
        return copy
    }
    
    /// Add strikethrough styling to this format.
    func strikethrough(_ enabled: Bool = true) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.strikethrough = enabled
        return copy
    }
    
    /// Set font size for this format.
    func fontSize(_ size: Int) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.fontSize = size
        return copy
    }
    
    /// Set font family for this format.
    func fontFamily(_ family: String) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.fontFamily = family
        return copy
    }
    
    /// Set foreground (text) color for this format.
    func foregroundColor(_ color: Color) -> CellFormat {
        var copy = self
        if copy.textFormat == nil { copy.textFormat = TextFormat() }
        copy.textFormat?.foregroundColor = color
        return copy
    }
}
