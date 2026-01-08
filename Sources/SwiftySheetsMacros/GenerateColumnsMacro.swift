import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct GenerateColumnsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var decls: [DeclSyntax] = []
        
        // Helper to convert index to column string (e.g., 1 -> A, 27 -> AA)
        func indexToColumn(_ index: Int) -> String {
            var column = ""
            var i = index
            while i > 0 {
                let remainder = (i - 1) % 26
                column = String(UnicodeScalar(65 + remainder)!) + column
                i = (i - 1) / 26
            }
            return column
        }
        
        // Generate A...ZZ (1...702)
        for i in 1...702 {
            let colName = indexToColumn(i)
            // public static let A = ColumnReference(index: 1)
            let decl = "public static let \(colName) = ColumnReference(index: \(i))"
            decls.append(DeclSyntax(stringLiteral: decl))
        }
        
        return decls
    }
}
