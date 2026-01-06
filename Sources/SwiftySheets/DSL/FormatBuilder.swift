import Foundation

/// A fluent builder for applying cell formatting.
/// Uses mutable state internally for efficiency, builds final format on apply().
/// ```swift
/// try await spreadsheet.format(#Range("A1:D1"))
///     .backgroundColor(.blue)
///     .bold()
///     .fontSize(14)
///     .apply()
/// ```
public final class FormatBuilder: Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    
    // Mutable state stored as nonisolated(unsafe) since we build synchronously
    private nonisolated(unsafe) var _backgroundColor: Color?
    private nonisolated(unsafe) var _bold: Bool?
    private nonisolated(unsafe) var _italic: Bool?
    private nonisolated(unsafe) var _underline: Bool?
    private nonisolated(unsafe) var _strikethrough: Bool?
    private nonisolated(unsafe) var _fontSize: Int?
    private nonisolated(unsafe) var _fontFamily: String?
    private nonisolated(unsafe) var _foregroundColor: Color?
    private nonisolated(unsafe) var _alignment: HorizontalAlignment?
    
    init(spreadsheet: Spreadsheet, range: SheetRange) {
        self.spreadsheet = spreadsheet
        self.range = range
    }
    
    // MARK: - Background
    
    /// Set the background color.
    @discardableResult
    public func backgroundColor(_ color: Color) -> FormatBuilder {
        _backgroundColor = color
        return self
    }
    
    // MARK: - Text Formatting
    
    /// Make text bold.
    @discardableResult
    public func bold(_ enabled: Bool = true) -> FormatBuilder {
        _bold = enabled
        return self
    }
    
    /// Make text italic.
    @discardableResult
    public func italic(_ enabled: Bool = true) -> FormatBuilder {
        _italic = enabled
        return self
    }
    
    /// Underline text.
    @discardableResult
    public func underline(_ enabled: Bool = true) -> FormatBuilder {
        _underline = enabled
        return self
    }
    
    /// Strikethrough text.
    @discardableResult
    public func strikethrough(_ enabled: Bool = true) -> FormatBuilder {
        _strikethrough = enabled
        return self
    }
    
    /// Set font size.
    @discardableResult
    public func fontSize(_ size: Int) -> FormatBuilder {
        _fontSize = size
        return self
    }
    
    /// Set font family.
    @discardableResult
    public func fontFamily(_ family: String) -> FormatBuilder {
        _fontFamily = family
        return self
    }
    
    /// Set text color.
    @discardableResult
    public func foregroundColor(_ color: Color) -> FormatBuilder {
        _foregroundColor = color
        return self
    }
    
    // MARK: - Alignment
    
    /// Set horizontal alignment.
    @discardableResult
    public func alignment(_ alignment: HorizontalAlignment) -> FormatBuilder {
        _alignment = alignment
        return self
    }
    
    // MARK: - Build & Execute
    
    /// Build the final CellFormat from accumulated state.
    private func build() -> CellFormat {
        var textFormat: TextFormat? = nil
        
        // Only create TextFormat if any text properties are set
        if _bold != nil || _italic != nil || _underline != nil || 
           _strikethrough != nil || _fontSize != nil || _fontFamily != nil || _foregroundColor != nil {
            textFormat = TextFormat(
                foregroundColor: _foregroundColor,
                fontFamily: _fontFamily,
                fontSize: _fontSize,
                bold: _bold,
                italic: _italic,
                strikethrough: _strikethrough,
                underline: _underline
            )
        }
        
        return CellFormat(
            backgroundColor: _backgroundColor,
            horizontalAlignment: _alignment,
            textFormat: textFormat
        )
    }
    
    /// Apply the formatting to the range.
    public func apply() async throws(SheetsError) {
        let format = build()
        try await spreadsheet.format(range: range, format: format)
    }
}
