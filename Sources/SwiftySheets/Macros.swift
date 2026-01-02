// Public Macro Declarations

@attached(member, names: arbitrary)
public macro SheetRow() = #externalMacro(module: "SwiftySheetsMacros", type: "SheetRowMacro")

@attached(peer)
public macro Column(_ name: String) = #externalMacro(module: "SwiftySheetsMacros", type: "ColumnMacro")

@attached(peer)
public macro Column(index: Int) = #externalMacro(module: "SwiftySheetsMacros", type: "ColumnMacro")
