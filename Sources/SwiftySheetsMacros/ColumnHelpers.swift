/// Shared infrastructure for macro implementations in SwiftySheetsMacros.

// MARK: - MacroError

/// A lightweight error type used to surface diagnostic messages from macro
/// expansion logic.  It is intentionally simple — macro errors are always
/// converted into SwiftDiagnostics before reaching the compiler and therefore
/// do not need localised descriptions or recovery options.
struct MacroError: Error {
    let message: String
}

// MARK: - Column letter helpers

/// Converts a spreadsheet column letter string to a 0-based column index.
///
/// The conversion is case-insensitive and supports multi-letter columns
/// (e.g., `"A"` → `0`, `"Z"` → `25`, `"AA"` → `26`).
///
/// - Parameter letter: A non-empty string composed only of ASCII letters A–Z.
/// - Returns: The 0-based column index.
/// - Throws: ``MacroError`` when `letter` is empty or contains characters
///   outside the range A–Z.
func columnLetterToIndex(_ letter: String) throws -> Int {
    guard !letter.isEmpty else {
        throw MacroError(message: "Column name cannot be empty")
    }
    var column = 0
    for char in letter.uppercased().unicodeScalars {
        guard char.value >= 65 && char.value <= 90 else { // A-Z
            throw MacroError(message: "Invalid column name '\(letter)'. use letters A-Z.")
        }
        column = column * 26 + (Int(char.value) - 64)
    }
    return column - 1
}

/// Converts a 1-based column index to a spreadsheet column letter string.
///
/// The inverse of ``columnLetterToIndex(_:)``.  Indices outside the positive
/// range return an empty string.
///
/// - Parameter index: A 1-based column index (e.g., `1` → `"A"`, `27` → `"AA"`).
/// - Returns: The corresponding column letter string, or `""` for non-positive
///   indices.
func indexToColumnLetter(_ index: Int) -> String {
    var column = ""
    var i = index
    while i > 0 {
        let remainder = (i - 1) % 26
        column = String(UnicodeScalar(65 + remainder)!) + column
        i = (i - 1) / 26
    }
    return column
}
