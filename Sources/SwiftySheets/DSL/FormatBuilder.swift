import Foundation

/// A fluent builder for applying cell formatting.
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
    private var cellFormat: CellFormat
    
    init(spreadsheet: Spreadsheet, range: SheetRange) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.cellFormat = CellFormat()
    }
    
    private init(spreadsheet: Spreadsheet, range: SheetRange, cellFormat: CellFormat) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.cellFormat = cellFormat
    }
    
    // MARK: - Background
    
    /// Set the background color.
    public func backgroundColor(_ color: Color) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.backgroundColor(color)
        return copy
    }
    
    // MARK: - Text Formatting
    
    /// Make text bold.
    public func bold(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.bold(enabled)
        return copy
    }
    
    /// Make text italic.
    public func italic(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.italic(enabled)
        return copy
    }
    
    /// Underline text.
    public func underline(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.underline(enabled)
        return copy
    }
    
    /// Strikethrough text.
    public func strikethrough(_ enabled: Bool = true) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.strikethrough(enabled)
        return copy
    }
    
    /// Set font size.
    public func fontSize(_ size: Int) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.fontSize(size)
        return copy
    }
    
    /// Set font family.
    public func fontFamily(_ family: String) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.fontFamily(family)
        return copy
    }
    
    /// Set text color.
    public func foregroundColor(_ color: Color) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.foregroundColor(color)
        return copy
    }
    
    // MARK: - Alignment
    
    /// Set horizontal alignment.
    public func alignment(_ alignment: HorizontalAlignment) -> FormatBuilder {
        var copy = self
        copy.cellFormat = cellFormat.alignment(alignment)
        return copy
    }
    
    // MARK: - Execute
    
    /// Apply the formatting to the range.
    public func apply() async throws(SheetsError) {
        try await spreadsheet.format(range: range, format: cellFormat)
    }
}
