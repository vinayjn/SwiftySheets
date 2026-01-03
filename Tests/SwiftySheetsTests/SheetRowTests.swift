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
    
    // MARK: - Date Types Tests
    
    @SheetRow
    struct DateRow: SheetRowCodable, Equatable {
        @Column("A") var isoDate: Date
        @Column("B", format: "yyyy-MM-dd") var customDate: Date
        @Column("C") var optionalDate: Date?
    }
    
    func testDateTypes() throws {
        let isoStr = "2023-01-01T10:00:00Z"
        let customStr = "2023-12-31"
        let row = [isoStr, customStr, ""]
        
        let obj = try DateRow(row: row)
        
        // Verify ISO
        let isoFormatter = ISO8601DateFormatter()
        XCTAssertEqual(obj.isoDate, isoFormatter.date(from: isoStr))
        
        // Verify Custom
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // formatter.timeZone = TimeZone(identifier: "UTC") // Macro uses default timezone? 
        // Note: DateFormatter default timezone is local. 
        // The macro generated code: `let f = DateFormatter(); f.dateFormat = ...`
        // So both test and macro use system local time. Should match.
        
        // We need to be careful about matching exact dates if time components differ due to defaults.
        // But since we parse the same string with same formatter config (default), it should be equal.
        let expectedDate = formatter.date(from: customStr)
        XCTAssertEqual(obj.customDate, expectedDate)
        
        XCTAssertNil(obj.optionalDate)
        
        // Test Encoding
        let encoded = try obj.encodeRow()
        XCTAssertEqual(encoded[0], isoStr)
        XCTAssertEqual(encoded[1], customStr)
    }
}
