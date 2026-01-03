// Public Macro Declarations

@attached(member, names: arbitrary)
public macro SheetRow() = #externalMacro(module: "SwiftySheetsMacros", type: "SheetRowMacro")

@attached(peer)
@attached(peer)
public macro Column(_ name: String, format: String? = nil) = #externalMacro(module: "SwiftySheetsMacros", type: "ColumnMacro")

@attached(peer)
public macro Column(index: Int, format: String? = nil) = #externalMacro(module: "SwiftySheetsMacros", type: "ColumnMacro")
