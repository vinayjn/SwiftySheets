---
name: swiftysheets
description: Expert guidance on SwiftySheets, a modern Swift library for Google Sheets API. Use when working with spreadsheet automation, reading/writing data, type-safe macros (@SheetRow, @Column), Query DSL, formatting, or Drive integration. Helps write safe, type-safe spreadsheet code.
---

# SwiftySheets Skill

This skill provides expert guidance on SwiftySheets, a modern Swift library for interacting with Google Sheets API. Built with Swift 6, Macros, and a Declarative DSL.

## Core Mental Model: The Spreadsheet Library

Think of SwiftySheets as a **bridge between Swift structs and Google Sheets rows**:

- **`Client`** = The receptionist (authenticates and talks to Google's servers)
- **`Spreadsheet`** = A specific document you're working with (like opening a file)
- **`@SheetRow` structs** = Your data models (rows become Swift objects)
- **`SheetRange`** = The coordinates (tells Google which cells you want)
- **`SheetQuery`** = A search assistant (filters and sorts your data locally)
- **`DriveClient`** = The file manager (lists, creates, deletes spreadsheet files)

You don't deal with raw JSON or HTTP. SwiftySheets handles the plumbing.

## Authentication

Three options exist, each for different use cases:

```swift
// 1. Service Account (Server-side scripts, bots)
let credentials = try ServiceAccountCredentials(jsonPath: "service-account.json")

// 2. OAuth 2.0 (Mobile apps - users sign in with their Google account)
let credentials = OAuthCredentials(accessToken: userAccessToken)
// Or with automatic refresh:
let credentials = OAuthCredentials { await getCurrentUserToken() }

// 3. API Key (Read-only public data)
let credentials = APIKeyCredentials(apiKey: "YOUR_API_KEY")

// All credentials flow through the same Client
let client = Client(credentials: credentials)
```

**Rule**: Service accounts are for servers. OAuth is for apps. API keys are for public data.

## The @SheetRow Macro

This is the magic. It transforms a Swift struct into a two-way bridge with spreadsheet rows.

```swift
@SheetRow
struct User {
    @Column("A") var name: String
    @Column("B") var email: String
    @Column("C") var score: Int
    @Column("D") var joinDate: Date?
}
```

**What the macro generates:**
1. `init(row: [String])` - Parses a row array into your struct
2. `encodeRow() -> [String]` - Converts your struct back to a row array
3. A memberwise initializer for convenience

**Supported types**: `String`, `Int`, `Double`, `Bool`, `Date`, and their optional variants.

**For dates**, you can specify format:
```swift
@Column("D", dateFormat: "yyyy-MM-dd") var joinDate: Date?
```

## Column DSL: Type-Safe Cell References

Instead of error-prone strings like `"A1"`, use the `Column` enum:

```swift
// Type-safe cell reference
Column.A[1]           // → "A1"
Column.B[5]           // → "B5"
Column.AA[100]        // → "AA100"

// Ranges using Swift operators
Column.A...Column.D              // → "A:D" (entire columns)
Column.A[1]...Column.B[10]       // → "A1:B10" (specific rectangle)

// Dynamic strings (when you must parse runtime input)
try SheetRange(parsing: "A1:B10")
```

**Rule**: Prefer the Column DSL. Use `SheetRange(parsing:)` only for user input.

## Reading and Writing Data

### Reading Typed Data

```swift
let spreadsheet = try await client.spreadsheet(id: "your-spreadsheet-id")

// Read rows as your @SheetRow type
let users: [User] = try await spreadsheet.values(range: #Range("Sheet1!A:D"))

// Read raw strings  
let raw: [[String]] = try await spreadsheet.values(range: Column.A[1]...Column.D[100])
```

### Writing Data

```swift
// Append new rows (after existing data)
let newUsers = [User(name: "Alice", email: "a@test.com", score: 100)]
try await spreadsheet.appendValues(range: #Range("Sheet1!A1"), values: newUsers)

// Overwrite specific range
try await spreadsheet.updateValues(range: Column.A[1]...Column.A[3], values: users)
```

### Subscript Syntax (Quick Operations)

```swift
// Read single cell
let name = try await spreadsheet[Column.A[1]].stringValue()

// Write single cell
try await spreadsheet[Column.B[2]].set("Updated Value")

// Clear a range
try await spreadsheet[Column.C[1]...Column.C[10]].clear()
```

## Query DSL: Filter, Sort, Paginate

Like SQL for your spreadsheet data, but type-safe with KeyPaths:

```swift
let results = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.score, greaterThan: 80)           // Filter
    .where(\.email, endsWith: "@company.com")  // Chain filters (AND)
    .sorted(by: \.score, ascending: false)     // Sort
    .offset(20)                                // Skip rows (pagination)
    .limit(10)                                 // Take N rows
    .execute()                                 // Run it
```

### Available Filter Operations

| Method | Example |
|--------|---------|
| `where(_:equals:)` | `.where(\.status, equals: "Active")` |
| `where(_:notEquals:)` | `.where(\.status, notEquals: "Deleted")` |
| `where(_:greaterThan:)` | `.where(\.score, greaterThan: 50)` |
| `where(_:lessThan:)` | `.where(\.age, lessThan: 30)` |
| `where(_:between:)` | `.where(\.score, between: 50...100)` |
| `where(_:contains:)` | `.where(\.name, contains: "Smith")` |
| `where(_:startsWith:)` | `.where(\.email, startsWith: "admin")` |
| `where(_:endsWith:)` | `.where(\.email, endsWith: "@test.com")` |
| `whereNil(_:)` | `.whereNil(\.manager)` |
| `whereNotNil(_:)` | `.whereNotNil(\.nickname)` |
| `filter(_:)` | `.filter { $0.score > 50 && $0.isActive }` |
| `or(_:)` | `.or { $0.where(\.isAdmin, equals: true) }` |

### Execution Methods

```swift
.execute()  // → [T] all matching rows
.first()    // → T? first matching row
.count()    // → Int count of matches
```

**Important**: Filtering happens client-side. Google Sheets API doesn't support server-side filtering. Minimize data transfer by using specific ranges.

## Formatting DSL

Apply styles fluently:

```swift
try await spreadsheet.format(Column.A[1]...Column.D[1])
    .backgroundColor(.blue)
    .foregroundColor(.white)
    .bold()
    .fontSize(12)
    .alignment(.center)
    .apply()
```

## Batch Operations

Combine multiple structural changes in one API call:

```swift
try await spreadsheet.batchUpdate {
    AddSheet("Q1 Report")
    DeleteSheet(id: oldSheetID)
    ResizeSheet(sheetId: 0, rows: 500, columns: 10)
}
```

## Drive Integration

Manage spreadsheet files directly:

```swift
// List spreadsheets with fluent query
let reports = try await client.drive.list()
    .spreadsheets()
    .notTrashed()
    .nameContains("Report")
    .execute()

// Create new spreadsheet
let newFile = try await client.drive.create(name: "New Budget")

// Delete
try await client.drive.delete(id: fileId)
```

## Error Handling

SwiftySheets uses typed errors:

```swift
do throws(SheetsError) {
    let users = try await spreadsheet.values(range: #Range("A:D"))
} catch {
    switch error {
    case .authenticationFailed:
        // Token expired or invalid
    case .permissionDenied(let message):
        // Share the sheet with your service account email
    case .spreadsheetNotFound:
        // Wrong spreadsheet ID
    case .rateLimitExceeded(let retryAfter):
        // Wait and retry
    case .quotaExceeded(let retryAfter):
        // Daily quota hit
    case .networkError(let reason):
        // Connection issue
    case .invalidRequest:
        // Malformed request
    case .invalidResponse(let status):
        // Unexpected API response
    case .apiError(let details):
        // Google API specific error
    case .invalidRange(let message):
        // Bad range format
    }
}
```

## Thread Safety

- **`Client` is an actor** - all API calls are thread-safe
- **All types are `Sendable`** - safe to pass across concurrency boundaries
- **Fully async/await** - no callback hell

## Common Patterns

### Pagination

```swift
// Get page 3 (10 items per page)
let page3 = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .sorted(by: \.createdAt, ascending: false)
    .offset(20)  // Skip pages 1-2
    .limit(10)   // Get page 3
    .execute()
```

### Conditional Queries

```swift
// Active users OR admins
let users = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.isActive, equals: true)
    .or { $0.where(\.isAdmin, equals: true) }
    .execute()
```

### Bulk Insert

```swift
let newRecords = (1...100).map { User(name: "User \($0)", email: "u\($0)@test.com", score: $0) }
try await spreadsheet.appendValues(range: #Range("Sheet1!A1"), values: newRecords)
```

## Common Mistakes to Avoid

### 1. Forgetting to share with service account
```swift
// This will fail with permissionDenied
let spreadsheet = try await client.spreadsheet(id: "some-id")
// Fix: Share the Google Sheet with your service account email (xxx@project.iam.gserviceaccount.com)
```

### 2. Using raw strings instead of Column DSL
```swift
// Fragile - typos cause runtime failures
let range = try SheetRange(parsing: "A1:B10")

// Better - compile-time safety
let range = Column.A[1]...Column.B[10]
```

### 3. Fetching too much data
```swift
// Downloads entire sheet
let all = try await spreadsheet.values(range: Column.A...Column.Z)

// Better - specify what you need
let subset = try await spreadsheet.values(range: Column.A[1]...Column.D[100])
```

### 4. Not handling token expiration (OAuth)
```swift
// Token will expire
let credentials = OAuthCredentials(accessToken: staticToken)

// Better - auto-refresh
let credentials = OAuthCredentials { await getRefreshedToken() }
```

## Quick Reference

| Task | Code |
|------|------|
| Create client | `let client = Client(credentials: creds)` |
| Get spreadsheet | `try await client.spreadsheet(id: "...")` |
| Read typed rows | `try await spreadsheet.values(range: ..., type: MyType.self)` |
| Append rows | `try await spreadsheet.appendValues(range: ..., values: [...])` |
| Query with filter | `spreadsheet.query(T.self, in: range).where(...).execute()` |
| Format cells | `spreadsheet.format(range).bold().apply()` |
| List Drive files | `client.drive.list().spreadsheets().execute()` |

## Further Reading

- [Authentication Guide](Documentation/Authentication.md) - Detailed auth setup
- [Query DSL Reference](Documentation/QueryDSL.md) - All filter/sort operations
