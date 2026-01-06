import XCTest
@testable import SwiftySheets

final class CellValueTests: XCTestCase {
    
    func testEncoding() throws {
        let s = CellValue.string("Hello")
        let n = CellValue.number(123.45)
        let b = CellValue.bool(true)
        let f = CellValue.formula("=SUM(A1:B2)")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        // precise string checks depend on implementation details of JSONEncoder, 
        // but we expect specific keys.
        
        let sData = try encoder.encode(s)
        let nData = try encoder.encode(n)
        let bData = try encoder.encode(b)
        let fData = try encoder.encode(f)
        
        let sStr = String(data: sData, encoding: .utf8)!
        let nStr = String(data: nData, encoding: .utf8)!
        let bStr = String(data: bData, encoding: .utf8)!
        let fStr = String(data: fData, encoding: .utf8)!
        
        XCTAssertEqual(sStr, #"{"stringValue":"Hello"}"#)
        XCTAssertEqual(nStr, #"{"numberValue":123.45}"#)
        XCTAssertEqual(bStr, #"{"boolValue":true}"#)
        XCTAssertEqual(fStr, #"{"formulaValue":"=SUM(A1:B2)"}"#)
    }
    
    func testDecoding() throws {
        let json = #"{"stringValue": "test"}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CellValue.self, from: data)
        
        if case .string(let val) = decoded {
            XCTAssertEqual(val, "test")
        } else {
            XCTFail("Failed to decode string")
        }
    }
}
