import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

public struct SheetRowMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: SimpleDiagnosticMessage(message: "@SheetRow can only be applied to structs", diagnosticID: MessageID(domain: "SwiftySheets", id: "InvalidType"), severity: .error)))
            return []
        }
        
        let members = structDecl.memberBlock.members
        let storedProperties = members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
        
        // 1. Generate init(row: [String])
        var initBody = ""
        
        for property in storedProperties {
            guard let binding = property.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let type = binding.typeAnnotation?.type.description else {
                continue
            }
            
            // Check for @Column attribute
            let columnIndex: Int
            if let attribute = property.attributes.first(where: {
                $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Column"
            }), let args = attribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
                // Handle @Column("A") or @Column(index: 0)
                if let stringLiteral = args.first?.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                    columnIndex = columnLetterToIndex(stringLiteral)
                } else if let intLiteral = args.first?.expression.as(IntegerLiteralExprSyntax.self)?.literal.text {
                    columnIndex = Int(intLiteral) ?? 0
                } else {
                    columnIndex = 0 // Default or Error
                }
            } else {
                // Default to 0 or error? Or skip?
                // For now, let's skip non-annotated or implement auto-increment if we want
                continue 
            }
            
            // Generate decode logic
            // This assumes properties are String or basic types.
            // Ideally we check type but for MVP let's support String and Int
            if type.contains("String") {
                initBody += "self.\(name) = row.count > \(columnIndex) ? row[\(columnIndex)] : \"\"\n"
            } else if type.contains("Int") {
                initBody += "self.\(name) = (row.count > \(columnIndex) ? Int(row[\(columnIndex)]) : nil) ?? 0\n"
            }
        }
        
        let initDecl = """
        public init(row: [String]) throws {
            \(initBody)
        }
        """
        
        // 2. Generate encodeRow() -> [String]
        var maxIndex = 0
        var usageStmts = ""
        
        for property in storedProperties {
            // Re-parsing logic (should be factored out but duplicating for now for speed)
             guard let binding = property.bindings.first,
                  let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                continue
            }
            
            let columnIndex: Int
            if let attribute = property.attributes.first(where: {
                $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Column"
            }), let args = attribute.as(AttributeSyntax.self)?.arguments?.as(LabeledExprListSyntax.self) {
                if let stringLiteral = args.first?.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                    columnIndex = columnLetterToIndex(stringLiteral)
                } else if let intLiteral = args.first?.expression.as(IntegerLiteralExprSyntax.self)?.literal.text {
                    columnIndex = Int(intLiteral) ?? 0
                } else {
                    columnIndex = 0
                }
            } else {
                continue 
            }
            
            if columnIndex > maxIndex { maxIndex = columnIndex }
            usageStmts += "if values.count > \(columnIndex) { values[\(columnIndex)] = String(self.\(name)) }\n"
        }
        
        let encodeDecl = """
        public func encodeRow() throws -> [String] {
            var values = Array(repeating: "", count: \(maxIndex + 1))
            \(usageStmts)
            return values
        }
        """
        
        
        // 3. Generate memberwise init
        var memberwiseParams: [String] = []
        var memberwiseAssigns: [String] = []
        
        for property in storedProperties {
             guard let binding = property.bindings.first,
                   let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                   let type = binding.typeAnnotation?.type.description else {
                continue
            }
            memberwiseParams.append("\(name): \(type)")
            memberwiseAssigns.append("self.\(name) = \(name)")
        }
        
        let memberwiseInit = """
        public init(\(memberwiseParams.joined(separator: ", "))) {
            \(memberwiseAssigns.joined(separator: "\n    "))
        }
        """
        
        return [DeclSyntax(stringLiteral: initDecl), DeclSyntax(stringLiteral: encodeDecl), DeclSyntax(stringLiteral: memberwiseInit)]
    }
    
    private static func columnLetterToIndex(_ letter: String) -> Int {
        // Simple A -> 0 conversion
        let uppercase = letter.uppercased()
        guard let scalar = uppercase.unicodeScalars.first else { return 0 }
        return Int(scalar.value) - 65
    }
}

public struct ColumnMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [] // Marker macro, no expansion
    }
}

struct SimpleDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity
}
