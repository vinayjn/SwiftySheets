# SwiftySheets 📊

A modern, type-safe Swift library for interacting with the Google Sheets API. Built with **Swift Concurrency**, **Macros**, and a **Declarative DSL** to make spreadsheet automation strictly typed and effortless.

## ✨ Features

- **🚀 Modern Concurrency**: Fully `async`/`await` powered.
- **🛡️ Type-Safe Macros**: Map rows to structs securely with `@SheetRow` and `@Column`.
- **🏗️ Declarative DSL**: Manage sheets using SwiftUI-like syntax (`AddSheet`, `FormatCells`).
- **🔒 Strict Validation**: Compile-time safety for column names ("A", "B", etc).
- **🔑 Secure Auth**: Built-in Service Account authentication.

## 📦 Installation

Add SwiftySheets to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vinayjn/SwiftySheets.git", from: "1.0.0")
]
```

## 🚀 Quick Start

### 1. Setup Client

```swift
import SwiftySheets

let credentials = try ServiceAccountCredentials(jsonPath: "path/to/service-account.json")
let client = Client(credentials: credentials)
```

### 2. Define Your Model (Macros)

Use `@SheetRow` to map Swift structs to spreadsheet rows effortlessly.

```swift
@SheetRow
struct User {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column("C") var score: Int
    @Column("D") var joinDate: Date? // Automatically handles ISO8601
}
```
*Note: `@Column` enforces strict A-Z notation validation at compile time!*

### 3. Read & Write Data

```swift
let spreadsheet = try await client.spreadsheet(id: "spreadsheet-id")

// READ (Typesafe)
let users = try await spreadsheet.values(range: "Sheet1!A:D", type: User.self)

// WRITE (Typesafe)
let newUsers = [User(name: "Alice", email: "alice@test.com", score: 100, joinDate: Date())]
try await spreadsheet.appendValues(range: "Sheet1!A1", values: newUsers)
```

## 🛠️ Declarative DSL (Batch Updates)

SwiftySheets offers a declarative API for batch operations, similar to SwiftUI.

```swift
// Add a sheet, format header, and delete an old sheet in ONE request
try await spreadsheet.batchUpdate {
    AddSheet("Q1 Report")
    
    FormatCells(sheet: q1Sheet, range: "A1:Z1", format: CellFormat(
        backgroundColor: .blue,
        textFormat: TextFormat(bold: true, foregroundColor: .white)
    ))
    
    DeleteSheet(id: oldSheetID)
}
```

## 🎨 Advanced Features

### Formatting
```swift
try await spreadsheet.format(range: "Sheet1!A1", format: CellFormat(backgroundColor: .red))
```

### Sorting & Clearing
```swift
try await spreadsheet.sort(range: "Sheet1!A2:C", column: 0, ascending: true)
try await spreadsheet.clearValues(range: "Sheet1!D1:D100")
```

### 🚕 Drive Integration

SwiftySheets now includes a `DriveClient` to manage your files directly.

```swift
// List Spreadsheets
let files = try await client.drive.list(query: DriveQuery.spreadsheets.and(.notTrashed))
for file in files {
    print("\(file.name) (\(file.id))")
}

// Create & Delete
let newFile = try await client.drive.create(name: "Backup", mimeType: "application/json")
try await client.drive.delete(id: newFile.id)
```

### Raw Access
If you don't need models, you can always fall back to raw strings:
```swift
let rawValues: [[String]] = try await spreadsheet.values(range: "Sheet1!A1:B2")
```

## 🧪 Testing

SwiftySheets includes a comprehensive test suite covering Unit, Integration, and Macro expansion.

```bash
swift test
```

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.