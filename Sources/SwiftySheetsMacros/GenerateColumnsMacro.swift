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
        
        // Generate A...ZZ (1...702)
        for i in 1...702 {
            let colName = indexToColumnLetter(i)
            // public static let A = ColumnReference(index: 1)
            let decl = "public static let \(colName) = ColumnReference(index: \(i))"
            decls.append(DeclSyntax(stringLiteral: decl))
        }
        
        return decls
    }
}
