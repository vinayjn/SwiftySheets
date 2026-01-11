# SwiftySheets 📊

A modern, type-safe Swift library for interacting with the Google Sheets API. Built with **Swift 6**, **Macros**, and a **Declarative DSL** to make spreadsheet automation strictly typed, thread-safe, and effortless.

## ✨ Features

- **🚀 Modern Concurrency**: Actor-based `Client`, fully `async`/`await` powered, and strictly `Sendable`.
- **🛡️ Type-Safe Macros**: Map rows to structs securely with `@SheetRow` and `@Column`.
- **⚡️ Autocomplete DSL**: Access columns safely (`Column.A[1]`) with compiler-generated static properties.
- **🔍 Fluent Query DSL**: Filter, sort, and limit data using Swift KeyPaths (`.where(\.age, equals: 25)`).
- **🌊 Fluent Builders**: Chainable APIs for queries, formatting, and Drive operations.
- **🎨 Formatting DSL**: Declarative syntax for styling cells (`BackgroundColor(.blue)`).
- **🧮 Subscripts**: Intuitive access to ranges (`spreadsheet[Column.A[1]...Column.B[5]]`).
- **🔐 Typed Errors**: Explicit error handling with `SheetsError`.
- **🚕 Drive Integration**: Built-in support for managing Drive files.

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

// For OAuth (mobile) or API Key support, see [Authentication Guide](Documentation/Authentication.md).
```

### 2. Define Your Model

Use `@SheetRow` to map Swift structs to spreadsheet rows.

```swift
@SheetRow
struct User {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column("C") var score: Int
    @Column("D") var joinDate: Date? // Automatically handles ISO8601
}
```

### 3. Read & Write Data

```swift
let spreadsheet = try await client.spreadsheet(id: "spreadsheet-id")

// READ (Type-Safe)
let users: [User] = try await spreadsheet.values(range: #Range("Sheet1!A:D"))

// WRITE
let newUsers = [User(name: "Alice", email: "alice@test.com", score: 100, joinDate: Date())]
try await spreadsheet.appendValues(range: #Range("Sheet1!A1"), values: newUsers)

// SUBSCRIPTS (Type-Safe)
let cellValue = try await spreadsheet[Column.A[1]].stringValue()
try await spreadsheet[Column.B[2]].set("Updated Value")
try await spreadsheet[Column.C[1]...Column.C[10]].clear()

// Dynamic Strings (Explicit Parsing)
try await spreadsheet[try SheetRange(parsing: "A1")].set("Dynamic")
```

## 💡 Advanced Usage

### 🔍 Query DSL
Filter, sort, and paginate data with a fluent, type-safe API. [📚 Full Reference](Documentation/QueryDSL.md)
```swift
// Simple query
let highScorers = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.score, greaterThan: 80)
    .sorted(by: \.score, ascending: false)
    .execute()

// Complex query with filtering + sorting + pagination
let page3ActiveUsers = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.isActive, equals: true)
    .where(\.score, greaterThan: 50)
    .where(\.email, contains: "@company.com")
    .sorted(by: \.score, ascending: false)
    .offset(20)  // Skip first 20 (pages 1-2)
    .limit(10)   // Get 10 (page 3)
    .execute()

// Quick helpers
let count = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.isActive, equals: true)
    .count()

let topUser = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .sorted(by: \.score, ascending: false)
    .first()
```

### 🎨 Cell Formatting
Apply styles with a fluent builder.
```swift
try await spreadsheet.format(Column.A[1]...Column.D[1])
    .backgroundColor(.blue)
    .bold()
    .foregroundColor(.white)
    .fontSize(12)
    .alignment(.center)
    .apply()
```

### 🛠️ Batch Operations
Combine multiple operations into a single API request for performance.
```swift
try await spreadsheet.batchUpdate {
    AddSheet("Q1 Report")
    DeleteSheet(id: oldSheetID)
}
```

### 🚕 Drive Management
```swift
// List with fluent query builder
let reports = try await client.drive.list()
    .spreadsheets()
    .notTrashed()
    .nameContains("Report")
    .execute()

// Create new spreadsheet
let newFile = try await client.drive.create(name: "New Budget")
```

## 🧪 Testing

SwiftySheets includes a comprehensive test suite (Unit & Integration).

```bash
swift test
```

## 🤖 AI Coding Agents

SwiftySheets includes a comprehensive [skills document](.agent/skills/swiftysheets.md) for AI coding assistants. If you're using an AI-powered IDE or coding agent, it can reference this file to understand the library's APIs, patterns, and best practices.

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.