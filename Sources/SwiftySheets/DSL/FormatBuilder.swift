import Foundation

/// A fluent builder for applying cell formatting.
/// Accumulates formatting options via copy-on-return chaining, then applies on `apply()`.
/// ```swift
/// try await spreadsheet.format(#Range("A1:D1"))
///     .backgroundColor(.blue)
///     .bold()
///     .fontSize(14)
///     .apply()
/// ```
public struct FormatBuilder: Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange

    private var _backgroundColor: Color?
    private var _bold: Bool?
    private var _italic: Bool?
    private var _underline: Bool?
    private var _strikethrough: Bool?
    private var _fontSize: Int?
    private var _fontFamily: String?
    private var _foregroundColor: Color?
    private var _alignment: HorizontalAlignment?

    init(spreadsheet: Spreadsheet, range: SheetRange) {
        self.spreadsheet = spreadsheet
        self.range = range
    }

    // MARK: - Background

    /// Set the background color.
    public func backgroundColor(_ color: Color) -> FormatBuilder {
        var copy = self
        copy._backgroundColor = color
        return copy
    }

    // MARK: - Text Formatting

    /// Make text bold.
    public func bold(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy._bold = enabled
        return copy
    }

    /// Make text italic.
    public func italic(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy._italic = enabled
        return copy
    }

    /// Underline text.
    public func underline(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy._underline = enabled
        return copy
    }

    /// Strikethrough text.
    public func strikethrough(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy._strikethrough = enabled
        return copy
    }

    /// Set font size.
    public func fontSize(_ size: Int) -> FormatBuilder {
        var copy = self
        copy._fontSize = size
        return copy
    }

    /// Set font family.
    public func fontFamily(_ family: String) -> FormatBuilder {
        var copy = self
        copy._fontFamily = family
        return copy
    }

    /// Set text color.
    public func foregroundColor(_ color: Color) -> FormatBuilder {
        var copy = self
        copy._foregroundColor = color
        return copy
    }

    // MARK: - Alignment

    /// Set horizontal alignment.
    public func alignment(_ alignment: HorizontalAlignment) -> FormatBuilder {
        var copy = self
        copy._alignment = alignment
        return copy
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
