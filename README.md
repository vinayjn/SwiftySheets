# SwiftySheets

A modern, type-safe Swift library for interacting with Google Sheets API, built with Swift Concurrency and Macros.

## Features

- **Modern Concurrency**: Async/await based API.
- **Type-Safe Macros**: `@SheetRow` and `@Column` macros for easy object mapping.
- **Declarative DSL**: SwiftUI-like syntax for batch updates (e.g., creating sheets).
- **Service Account Auth**: Secure server-side authentication.
- **Comprehensive API**: Read, Write, Append, and Manage Sheets.

## Installation

Add SwiftySheets to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vinayjn/SwiftySheets.git", from: "1.0.0")
]
```

## Quick Start

### 1. Setup Client

```swift
import SwiftySheets

let credentials = try ServiceAccountCredentials(jsonPath: "/path/to/service-account.json")
let client = Client(credentials: credentials)
```

### 2. Access a Spreadsheet

```swift
let spreadsheet = try await client.spreadsheet(id: "your-spreadsheet-id")
print("Title: \(spreadsheet.metadata.properties.title)")
```

### 3. Define Data Models (Macros)

Use the `@SheetRow` macro to map Swift structs to spreadsheet rows.

```swift
@SheetRow
struct User {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column(index: 2) var score: Int
}
```

### 4. Read Data

```swift
// Read rows as directly mapped objects
let users = try await spreadsheet.values(
    range: "Sheet1!A1:C",
    type: User.self
)

for user in users {
    print("\(user.name): \(user.score)")
}
```

### 5. Write Data

```swift
let newUsers = [
    User(name: "Alice", email: "alice@example.com", score: 100),
    User(name: "Bob", email: "bob@example.com", score: 95)
]

// Encode objects to raw values
let values = try newUsers.map { try $0.encodeRow() }

// Update values
let result = try await spreadsheet.updateValues(
    range: "Sheet1!A1",
    values: values
)
```

### 6. Manage Sheets (DSL)

Use the declarative DSL for batch updates like adding or deleting sheets.

```swift
// Add a new sheet and delete an old one in a single batch request
let response = try await spreadsheet.batchUpdate {
    AddSheet("Quarterly Report") {
        GridProperties(rowCount: 100, columnCount: 20)
        TabColor(red: 1.0, green: 0.0, blue: 0.0) // Red tab
    }
    
    DeleteSheet(id: oldSheetId)
}
```

## Running the Demo

This repository includes a CLI demo. To run it, you need a Google Service Account JSON file and a Spreadsheet ID.

```bash
# Set environment variables
export SWIFTYSHEETS_SERVICE_ACCOUNT_PATH="/path/to/your/service_account.json"
export SWIFTYSHEETS_SPREADSHEET_ID="your_spreadsheet_id"

# Run the demo
swift run SwiftySheetsDemo
```

## Advanced Usage

### Raw Values
You can also read/write raw string arrays if you don't want to use Codable models.

```swift
let values = try await spreadsheet.values(range: "Sheet1!A1:B2")
// values is [[String]]
```

### Append Data
```swift
try await spreadsheet.appendValues(
    range: "Sheet1!A1",
    values: [["New Entry", "123"]]
)
```

## License

MIT License. See [LICENSE](LICENSE) for details.