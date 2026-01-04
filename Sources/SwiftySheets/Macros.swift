// Public Macro Declarations

@attached(member, names: named(init), named(encodeRow))
@attached(extension, conformances: SheetRowCodable, Equatable, Hashable)
public macro SheetRow() = #externalMacro(module: "SwiftySheetsMacros", type: "SheetRowMacro")

@freestanding(expression)
public macro Range(_ value: String) -> SheetRange = #externalMacro(module: "SwiftySheetsMacros", type: "RangeMacro")

@attached(peer)
@attached(peer)
public macro Column(_ name: String, format: String? = nil) = #externalMacro(module: "SwiftySheetsMacros", type: "ColumnMacro")

@attached(peer)
public macro Column(index: Int, format: String? = nil) = #externalMacro(module: "SwiftySheetsMacros", type: "ColumnMacro")
