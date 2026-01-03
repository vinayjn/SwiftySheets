import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

public struct SheetRowMacro: MemberMacro {
    
    struct PropInfo {
        let name: String
        let type: String
        let columnIndex: Int
    }
    
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
        
        var props: [PropInfo] = []
        
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
            props.append(PropInfo(name: name, type: type, columnIndex: columnIndex))
        }
        
        // 1. Generate init(row: [String])
        var initBody = ""
        for p in props {
            let col = p.columnIndex
            let type = p.type.trimmingCharacters(in: .whitespaces)
            let isOptional = type.hasSuffix("?")
            let cleanType = isOptional ? String(type.dropLast()) : type
            
            let safeRead = "row.count > \(col) ? row[\(col)] : \"\""
            
            let rawVar = "raw_\(p.name)"
            
            // Conversion logic
            var conversion = ""
            if cleanType == "String" {
                if isOptional {
                    conversion = "let \(rawVar) = \(safeRead); self.\(p.name) = \(rawVar).isEmpty ? nil : \(rawVar)"
                } else {
                    conversion = "self.\(p.name) = \(safeRead)"
                }
            } else if cleanType == "Int" {
                if isOptional {
                    conversion = "let \(rawVar) = \(safeRead); self.\(p.name) = \(rawVar).isEmpty ? nil : Int(\(rawVar))"
                } else {
                    conversion = "self.\(p.name) = Int(\(safeRead)) ?? 0"
                }
            } else if cleanType == "Double" {
                 if isOptional {
                    conversion = "let \(rawVar) = \(safeRead); self.\(p.name) = \(rawVar).isEmpty ? nil : Double(\(rawVar))"
                } else {
                    conversion = "self.\(p.name) = Double(\(safeRead)) ?? 0.0"
                }
            } else if cleanType == "Bool" {
                let boolParse = "((\(safeRead)).lowercased() == \"true\")"
                if isOptional {
                    conversion = "let \(rawVar) = \(safeRead); self.\(p.name) = \(rawVar).isEmpty ? nil : ((\(rawVar)).lowercased() == \"true\")"
                } else {
                    conversion = "self.\(p.name) = \(boolParse)"
                }
            } else {
                 if isOptional {
                    conversion = "self.\(p.name) = nil"
                 } else {
                    conversion = "// Unsupported type \(cleanType)"
                 }
            }
            
            initBody += "\n    // \(p.name): \(type)\n    \(conversion)"
        }
        
        let initDecl = """
        public init(row: [String]) throws {
            \(initBody)
        }
        """
        
        // 2. Generate encodeRow() -> [String]
        var maxIndex = 0
        for p in props { if p.columnIndex > maxIndex { maxIndex = p.columnIndex } }
        
        var usageStmts = ""
        for p in props {
            let col = p.columnIndex
            let type = p.type.trimmingCharacters(in: .whitespaces)
            let isOptional = type.hasSuffix("?")
            let cleanType = isOptional ? String(type.dropLast()) : type
            
            var encodeExpr = ""
            
            if cleanType == "String" {
                if isOptional {
                    encodeExpr = "self.\(p.name) ?? \"\""
                } else {
                    encodeExpr = "self.\(p.name)"
                }
            } else if cleanType == "Int" || cleanType == "Double" {
                if isOptional {
                    encodeExpr = "self.\(p.name).map(String.init) ?? \"\""
                } else {
                    encodeExpr = "String(self.\(p.name))"
                }
            } else if cleanType == "Bool" {
                if isOptional {
                    encodeExpr = "self.\(p.name).map { $0 ? \"TRUE\" : \"FALSE\" } ?? \"\""
                } else {
                    encodeExpr = "(self.\(p.name) ? \"TRUE\" : \"FALSE\")"
                }
            } else {
                encodeExpr = "\"\""
            }
            
            usageStmts += "if values.count > \(col) { values[\(col)] = \(encodeExpr) }\n"
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
        
        for p in props {
            memberwiseParams.append("\(p.name): \(p.type)")
            memberwiseAssigns.append("self.\(p.name) = \(p.name)")
        }
        
        let memberwiseInit = """
        public init(\(memberwiseParams.joined(separator: ", "))) {
            \(memberwiseAssigns.joined(separator: "\n    "))
        }
        """
        
        return [DeclSyntax(stringLiteral: initDecl), DeclSyntax(stringLiteral: encodeDecl), DeclSyntax(stringLiteral: memberwiseInit)]
    }
    
    private static func columnLetterToIndex(_ letter: String) -> Int {
        var column = 0
        for char in letter.uppercased().unicodeScalars {
            column = column * 26 + (Int(char.value) - 64)
        }
        return column - 1
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
