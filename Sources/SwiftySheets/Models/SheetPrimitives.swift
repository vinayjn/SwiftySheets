import Foundation

/// A validated column letter (A, B, ..., Z, AA, AB, ...).
/// Use string literals like `"A"` or initialize with `SheetColumn("AA")`.
public struct SheetColumn: Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Equatable {
    public let value: String
    
    /// Creates a column from a string. Throws if invalid.
    public init(_ value: String) throws {
        let v = value.uppercased()
        guard v.range(of: "^[A-Z]+$", options: .regularExpression) != nil else {
            throw SheetsError.invalidRange(message: "Invalid column letter: '\(value)'. Columns must be letters (A, B, AA...).")
        }
        self.value = v
    }
    
    /// Creates a column from a string literal. Traps if invalid (compile-time safety via macros recommended).
    public init(stringLiteral value: String) {
        // For literals, we trust compile-time validation via #Range macro.
        // If used without macro, this will trap - but that's intentional for static strings.
        do {
            try self.init(value)
        } catch {
            preconditionFailure("Invalid column literal: '\(value)'. Use #Range macro for compile-time safety.")
        }
    }
    
    /// Internal init that bypasses validation (for macro-generated code).
    internal init(unchecked value: String) {
        self.value = value.uppercased()
    }
    
    public var description: String { value }
}

/// A validated row index (1-based, positive integer).
public struct SheetRowIndex: Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible, Equatable {
    public let value: Int
    
    /// Creates a row index. Throws if not positive.
    public init(_ value: Int) throws {
        guard value > 0 else {
            throw SheetsError.invalidRange(message: "Invalid row index: \(value). Row indices must be positive (1-indexed).")
        }
        self.value = value
    }
    
    /// Creates a row index from an integer literal.
    public init(integerLiteral value: Int) {
        do {
            try self.init(value)
        } catch {
            preconditionFailure("Invalid row index literal: \(value). Must be positive.")
        }
    }
    
    /// Internal init that bypasses validation (for macro-generated code).
    internal init(unchecked value: Int) {
        self.value = value
    }
    
    public var description: String { String(value) }
}
