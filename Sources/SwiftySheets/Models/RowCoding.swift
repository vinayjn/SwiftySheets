import Foundation

public protocol SheetRowDecodable {
    init(row: [String]) throws
}

public protocol SheetRowEncodable {
    func encodeRow() throws -> [String]
}

public typealias SheetRowCodable = SheetRowDecodable & SheetRowEncodable

