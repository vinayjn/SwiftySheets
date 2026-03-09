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

    func testMacroDateUsesStaticFormatter() {
        #if canImport(SwiftySheetsMacros)
        assertMacroExpansion(
            """
            @SheetRow
            struct Record {
                @Column("A") var createdAt: Date
            }
            """,
            expandedSource: """
            struct Record {
                var createdAt: Date
            }

            extension Record: SheetRowCodable, Equatable, Hashable {
                private static let _iso8601Formatter = ISO8601DateFormatter()
                public init(row: [String]) throws {

                    // createdAt: Date
                    self.createdAt = Self._iso8601Formatter.date(from: row.count > 0 ? row[0] : "") ?? Date()
                }
                public func encodeRow() throws -> [String] {
                    var values = Array(repeating: "", count: 1)
                    if values.count > 0 { values[0] = Self._iso8601Formatter.string(from: self.createdAt) }
                    return values
                }
                public init(createdAt: Date) {
                    self.createdAt = createdAt
                }
            }
            """,
            macros: testMacros
        )
        #endif
    }

    func testMacroCustomDateFormatUsesStaticFormatter() {
        #if canImport(SwiftySheetsMacros)
        assertMacroExpansion(
            """
            @SheetRow
            struct Record {
                @Column("A", format: "yyyy-MM-dd") var date: Date
            }
            """,
            expandedSource: """
            struct Record {
                var date: Date
            }

            extension Record: SheetRowCodable, Equatable, Hashable {
                private static let _dateFormatter0: DateFormatter = {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    return f
                }()
                public init(row: [String]) throws {

                    // date: Date
                    self.date = Self._dateFormatter0.date(from: row.count > 0 ? row[0] : "") ?? Date()
                }
                public func encodeRow() throws -> [String] {
                    var values = Array(repeating: "", count: 1)
                    if values.count > 0 { values[0] = Self._dateFormatter0.string(from: self.date) }
                    return values
                }
                public init(date: Date) {
                    self.date = date
                }
            }
            """,
            macros: testMacros
        )
        #endif
    }
}
