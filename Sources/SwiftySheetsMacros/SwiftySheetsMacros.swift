import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftySheetsMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SheetRowMacro.self,
        ColumnMacro.self,
        RangeMacro.self
    ]
}
