import Foundation

public struct SheetColumn: Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Equatable {
    public let value: String
    
    public init(_ value: String) {
        // Validate A-Z, AA-ZZ
        // We allow lowercase and convert/validate?
        // Or strict?
        // Let's be helpful: Uppercased.
        let v = value.uppercased()
        guard v.range(of: "^[A-Z]+$", options: .regularExpression) != nil else {
            fatalError("Invalid column letter: '\(value)'. Columns must be letters (A, B, AA...).")
        }
        self.value = v
    }
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    public var description: String { value }
}

public struct SheetRowIndex: Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible, Equatable {
    public let value: Int
    
    public init(_ value: Int) {
        guard value > 0 else {
            fatalError("Invalid row index: \(value). Row indices must be positive (1-indexed).")
        }
        self.value = value
    }
    
    public init(integerLiteral value: Int) {
        self.init(value)
    }
    
    public var description: String { String(value) }
}
