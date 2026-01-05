import Foundation

// MARK: - Format Properties (Building blocks)

/// Protocol for format properties that can be used in the CellFormat builder
public protocol FormatProperty: Sendable {
    func apply(to format: inout CellFormat)
}

// MARK: - Background Color

public struct BackgroundColor: FormatProperty {
    private let color: Color
    
    public init(_ color: Color) {
        self.color = color
    }
    
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.color = Color(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    public func apply(to format: inout CellFormat) {
        format.backgroundColor = color
    }
}

// MARK: - Text Formatting

public struct Bold: FormatProperty {
    private let enabled: Bool
    
    public init(_ enabled: Bool = true) {
        self.enabled = enabled
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.bold = enabled
    }
}

public struct Italic: FormatProperty {
    private let enabled: Bool
    
    public init(_ enabled: Bool = true) {
        self.enabled = enabled
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.italic = enabled
    }
}

public struct Underline: FormatProperty {
    private let enabled: Bool
    
    public init(_ enabled: Bool = true) {
        self.enabled = enabled
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.underline = enabled
    }
}

public struct Strikethrough: FormatProperty {
    private let enabled: Bool
    
    public init(_ enabled: Bool = true) {
        self.enabled = enabled
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.strikethrough = enabled
    }
}

public struct FontSize: FormatProperty {
    private let size: Int
    
    public init(_ size: Int) {
        self.size = size
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.fontSize = size
    }
}

public struct FontFamily: FormatProperty {
    private let family: String
    
    public init(_ family: String) {
        self.family = family
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.fontFamily = family
    }
}

public struct ForegroundColor: FormatProperty {
    private let color: Color
    
    public init(_ color: Color) {
        self.color = color
    }
    
    public func apply(to format: inout CellFormat) {
        if format.textFormat == nil {
            format.textFormat = TextFormat()
        }
        format.textFormat?.foregroundColor = color
    }
}

// MARK: - Alignment

public struct Alignment: FormatProperty {
    private let alignment: HorizontalAlignment
    
    public init(_ alignment: HorizontalAlignment) {
        self.alignment = alignment
    }
    
    public static let left = Alignment(.left)
    public static let center = Alignment(.center)
    public static let right = Alignment(.right)
    
    public func apply(to format: inout CellFormat) {
        format.horizontalAlignment = alignment
    }
}

// MARK: - Result Builder

@resultBuilder
public struct CellFormatBuilder {
    public static func buildBlock(_ components: FormatProperty...) -> CellFormat {
        var format = CellFormat()
        for component in components {
            component.apply(to: &format)
        }
        return format
    }
    
    public static func buildOptional(_ component: FormatProperty?) -> FormatProperty {
        component ?? EmptyFormatProperty()
    }
    
    public static func buildEither(first component: FormatProperty) -> FormatProperty {
        component
    }
    
    public static func buildEither(second component: FormatProperty) -> FormatProperty {
        component
    }
    
    public static func buildArray(_ components: [FormatProperty]) -> FormatProperty {
        CompositeFormatProperty(properties: components)
    }
}

// Helper types for builder
private struct EmptyFormatProperty: FormatProperty {
    func apply(to format: inout CellFormat) {}
}

private struct CompositeFormatProperty: FormatProperty {
    let properties: [FormatProperty]
    
    func apply(to format: inout CellFormat) {
        for property in properties {
            property.apply(to: &format)
        }
    }
}
