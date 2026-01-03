@testable import SwiftySheets
import XCTest

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SheetRowTests: XCTestCase {
    
    // MARK: - Supported Types Tests
    
    @SheetRow
    struct AllTypes: SheetRowCodable, Equatable {
        @Column("A") var string: String
        @Column("B") var integer: Int
        @Column("C") var double: Double
        @Column("D") var boolean: Bool
        @Column("E") var optionalString: String?
        @Column("F") var optionalInt: Int?
    }
    
    func testAllTypes() throws {
        // Test Decoding
        let row = ["Hello", "42", "3.14", "TRUE", "Opt", ""]
        // Note: Row array might truncate trailing empty strings, so index 5 (F) might be missing for optionalInt
        
        // We need to support "TRUE"/"FALSE" for boolean as Google Sheets returns.
        
        let obj = try AllTypes(row: row)
        XCTAssertEqual(obj.string, "Hello")
        XCTAssertEqual(obj.integer, 42)
        XCTAssertEqual(obj.double, 3.14, accuracy: 0.001)
        XCTAssertEqual(obj.boolean, true)
        XCTAssertEqual(obj.optionalString, "Opt")
        // obj.optionalInt should be nil if empty string or missing
        XCTAssertNil(obj.optionalInt) 
        
        // Test Encoding
        let obj2 = AllTypes(string: "S", integer: 1, double: 1.5, boolean: false, optionalString: nil, optionalInt: 99)
        let encoded = try obj2.encodeRow()
        
        // C=1.5, D=FALSE (or false), E="", F=99
        // Allow slight variations in validation logic, but let's see what we implement.
        XCTAssertEqual(encoded[0], "S")
        XCTAssertEqual(encoded[1], "1")
        XCTAssertEqual(encoded[2], "1.5")
        XCTAssertEqual(encoded[3], "FALSE") // or FALSE
        XCTAssertEqual(encoded[4], "")
        XCTAssertEqual(encoded[5], "99")
    }
    
    // MARK: - Nesting Test (Expectation: Not Supported or Flat?)
    // While the user asked if it is supported, we know it will verify false currently.
    // So we won't add a failing test for it unless we plan to implement it.
}
