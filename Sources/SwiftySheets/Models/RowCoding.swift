import Foundation

public protocol SheetRowDecodable {
    init(row: [String]) throws
}

public protocol SheetRowEncodable {
    func encodeRow() throws -> [String]
}

public typealias SheetRowCodable = SheetRowDecodable & SheetRowEncodable

// Default implementation for basic types if needed, or specialized decoders
