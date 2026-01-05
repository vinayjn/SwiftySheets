import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

public struct RangeMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression,
              let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
              segments.count == 1,
              case let .stringSegment(segment)? = segments.first else {
            context.diagnose(Diagnostic(node: node, message: SimpleDiagnosticMessage(message: "#Range requires a static string literal", diagnosticID: MessageID(domain: "SwiftySheets", id: "InvalidRangeInput"), severity: .error)))
            return "SheetRange()"
        }
        
        let rawValue = segment.content.text
        
        // Validation Logic (A1 Notation)
        // Groups: 1=SheetName(incl quotes/!), 2=SheetName(pure), 3=StartCol, 4=StartRow, 5=EndPart, 6=EndCol, 7=EndRow
        let pattern = #"^('?([^'!]+)'?!)?([A-Za-z]+)(\d+)?(:([A-Za-z]+)(\d+)?)?$"#
        
        // Check Validity
        // Note: NSRegularExpression is available in macros (Foundation).
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
             // Should not happen with static pattern
            return "SheetRange()"
        }
        
        let range = NSRange(location: 0, length: rawValue.utf16.count)
        guard let match = regex.firstMatch(in: rawValue, options: [], range: range) else {
            context.diagnose(Diagnostic(node: node, message: SimpleDiagnosticMessage(message: "Invalid A1 notation: '\(rawValue)'. Expected format: 'Sheet!A1:B2' or 'A1'", diagnosticID: MessageID(domain: "SwiftySheets", id: "InvalidRangeFormat"), severity: .error)))
            return "SheetRange()"
        }
        
        // Helper to extract group
        func extract(_ group: Int) -> String? {
            guard group < match.numberOfRanges else { return nil }
            let r = match.range(at: group)
            if r.location == NSNotFound { return nil }
            return (rawValue as NSString).substring(with: r)
        }
        
        let sheetName = extract(2)
        let startCol = extract(3)
        let startRow = extract(4)
        let endCol = extract(6)
        let endRow = extract(7)
        
        // Validation: Logic
        // If : exists, EndCol OR EndRow must exist? Or redundant check?
        // Regex handles structure.
        
        // Construct optimized code
        var args: [String] = []
        if let s = sheetName { args.append("sheetName: \"\(s)\"") }
        if let sc = startCol { args.append("startColumn: \"\(sc)\"") }
        if let sr = startRow { args.append("startRow: \(sr)") }
        if let ec = endCol { args.append("endColumn: \"\(ec)\"") }
        if let er = endRow { args.append("endRow: \(er)") }
        
        return "SheetRange(\(raw: args.joined(separator: ", ")))"
    }
}
