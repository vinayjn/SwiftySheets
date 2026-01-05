import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(SwiftySheetsMacros)
import SwiftySheetsMacros

let testMacros: [String: Macro.Type] = [
    "SheetRow": SheetRowMacro.self,
    "Column": ColumnMacro.self // Column uses SheetRowMacro for processing but declared as PeerMacro
]
#endif

final class SheetRowMacroTests: XCTestCase {
    
    func testMacroValidationFail_InvalidCharacters() {
        #if canImport(SwiftySheetsMacros)
        assertMacroExpansion(
            """
            @SheetRow
            struct Test {
                @Column("1") var col: String
            }
            """,
            expandedSource: """
            struct Test {
                var col: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Invalid column name '1'. use letters A-Z.", line: 3, column: 13)
            ],
            macros: testMacros
        )
        #endif
    }
    
    func testMacroValidationFail_Empty() {
        #if canImport(SwiftySheetsMacros)
        assertMacroExpansion(
            """
            @SheetRow
            struct Test {
                @Column("") var col: String
            }
            """,
            expandedSource: """
            struct Test {
                var col: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Column name cannot be empty", line: 3, column: 13)
            ],
            macros: testMacros
        )
        #endif
    }
    
    func testMacroSuccess() {
        #if canImport(SwiftySheetsMacros)
        assertMacroExpansion(
            """
            @SheetRow
            struct Test {
                @Column("A") var col: String
            }
            """,
            expandedSource: """
            struct Test {
                var col: String
            }
            
            extension Test: SheetRowCodable, Equatable, Hashable {
                public init(row: [String]) throws {
            
                    // col: String
                    self.col = row.count > 0 ? row[0] : ""
                }
                public func encodeRow() throws -> [String] {
                    var values = Array(repeating: "", count: 1)
                    if values.count > 0 { values[0] = self.col }
                    return values
                }
                public init(col: String) {
                    self.col = col
                }
            }
            """,
            macros: testMacros
        )
        #endif
    }
}
