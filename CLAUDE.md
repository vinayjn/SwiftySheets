# SwiftySheets Development Guide

## Project Overview

SwiftySheets is a type-safe, Swifty wrapper around the Google Sheets API v4 and Google Drive API v3. It targets Swift 6.2+, macOS 13+, and iOS 15+. The library's goal is to be **world-class** — the best way to work with Google Sheets from Swift.

## Build & Test

```bash
swift build        # Build library + macros
swift test         # Run all tests (113+ currently)
```

All tests must pass before any commit. No `@testable import` in integration tests — only unit tests.

## Core Design Principles

### 1. Progressive Disclosure

Simple things must be simple. Complex things must be possible. A beginner should be productive in 5 minutes; a power user should never hit a wall.

```swift
// Simple (80% use case)
let rows = try await spreadsheet.values(range: #Range("A:D"))

// Intermediate
let employees: [Employee] = try await spreadsheet.values(range: #Range("A:D"), type: Employee.self)

// Advanced
let results = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
    .where(\.department, equals: "Engineering")
    .where(\.salary, greaterThan: 80000)
    .sorted(by: \.name)
    .limit(10)
    .execute()
```

### 2. Type Safety at Every Boundary

Never accept a raw `String` where a validated type exists. Compile-time validation is always preferred over runtime validation.

- Use `SheetRange` (not `String`) for ranges
- Use `#Range("A1:B2")` macro for compile-time validated ranges
- Use `SheetColumn` and `SheetRowIndex` for validated components
- Use typed throws `throws(SheetsError)` on every throwing function
- Use `@SheetRow` macro for compile-time row encoding/decoding
- Use `Sendable` constraints on all generic parameters and closures

### 3. Value Types by Default

All builders and data types are **structs**, not classes. This guarantees:
- No shared mutable state
- No data races (compiler-verified `Sendable`)
- Copy-on-return semantics for safe chaining

The only exception is `Client`, which is an **actor** (thread-safe by design).

### 4. Zero Unsafe Code in Public API

- No `!` force unwraps in library source
- No `as!` force casts
- No `@unchecked Sendable` without a documented safety justification comment
- No `nonisolated(unsafe)` without a documented safety justification comment
- No `try!` or `fatalError()` in library source (except `preconditionFailure` in `ExpressibleByStringLiteral` inits, which is intentional for misuse of literal syntax)

## Architecture Patterns

### Builder Pattern (Copy-on-Return)

Used by: `FormatBuilder`, `SheetQuery`, `DriveListBuilder`

Every builder method returns a **new copy** with the modification applied:

```swift
public func bold(_ enabled: Bool = true) -> FormatBuilder {
    var copy = self
    copy._bold = enabled
    return copy
}
```

Rules:
- Builder types are `struct` conforming to `Sendable`
- Private mutable state uses underscore prefix: `_limitCount`, `_backgroundColor`
- **No `@discardableResult`** on builder methods — discarding a struct return silently loses the modification
- `@discardableResult` is only used on **terminal operations** that return response objects the caller may ignore (e.g., `updateValues() -> UpdateValuesResponse`)
- Terminal methods are named by their action: `apply()`, `execute()`, `first()`, `count()`
- Builders are created by factory methods on their parent type, not by public initializers

### Result Builder Pattern

Used by: `@BatchUpdateBuilder`

Enables declarative DSL syntax for composing batch operations:

```swift
try await spreadsheet.batchUpdate {
    AddSheet("New Sheet")
    if needsHeader {
        FormatCells(sheet: sheet, range: headerRange, format: .bold())
    }
    ResizeSheet(sheetId: sheet.sheetId, rows: 1000, columns: 10)
}
```

Rules:
- The result builder is `@BatchUpdateBuilder` — always annotate the closure parameter
- Support `buildBlock`, `buildExpression`, `buildOptional`, `buildEither` for full if/else/optional support
- Individual operations implement `BatchRequestConvertible` protocol
- `BatchRequestConvertible` has a single requirement: `var request: BatchUpdateRequest.Request { get }`

### DSL Helper Pattern (BatchRequestConvertible)

Every batch update operation gets a **dedicated struct** that:
1. Has a descriptive name matching the operation (`AddSheet`, `DeleteSheet`, `MergeCells`, `InsertDimension`)
2. Takes Swift-native parameters (not raw API structures)
3. Implements `BatchRequestConvertible` to bridge to the API enum
4. Provides convenience overloads where useful (e.g., accept `Sheet` or `sheetId: Int`)

```swift
public struct InsertDimension: BatchRequestConvertible {
    let sheetId: Int
    let dimension: SortDimension
    let startIndex: Int
    let endIndex: Int

    public init(sheet: Sheet, dimension: SortDimension, startIndex: Int, endIndex: Int) {
        self.sheetId = sheet.sheetId
        // ...
    }

    public var request: BatchUpdateRequest.Request {
        // Build the API-level request structure
    }
}
```

Rules:
- DSL types live in `Sources/SwiftySheets/DSL/DSLHelpers.swift` (or split into focused files if they grow large)
- Always provide an `init` that takes `Sheet` for convenience, plus one taking `sheetId: Int` for direct use
- The `request` computed property builds the API structure — all mapping logic lives here
- Document any field masking behavior with comments (e.g., `fields: "gridProperties"`)

### Actor Pattern (Client)

`Client` is the single entry point for all API communication:

```swift
public actor Client: Sendable {
    private let transport: SheetsTransport
    public nonisolated var drive: DriveClient { ... }
}
```

Rules:
- `Client` is an `actor` — all methods are actor-isolated by default
- Properties returning lightweight `Sendable` types can be `nonisolated` (e.g., `drive`)
- `Client` methods take explicit `spreadsheetId: String` parameters
- `Spreadsheet` methods operate on `self.id` (captured at init time)
- Internal `makeRequest<T: Decodable & Sendable>()` is the single path for all HTTP calls
- Error mapping is centralized in `ResponseHandler`

### ResponseHandler Pattern

All HTTP response validation and error mapping is centralized in `ResponseHandler`:

```swift
enum ResponseHandler {
    static func validateAndDecode<T: Decodable & Sendable>(data:, response:) throws(SheetsError) -> T
    static func validate(data:, response:) throws(SheetsError)
    static func mapError(data:, statusCode:, headers:) -> SheetsError
}
```

Rules:
- `ResponseHandler` is a caseless `enum` (no instances)
- All functions are `static`
- Both `Client` and `DriveClient` use the same handler — no duplication
- HTTP status mapping: 401 → `.authenticationFailed`, 403 → `.permissionDenied`/`.quotaExceeded`, 404 → `.spreadsheetNotFound`, 429 → `.rateLimitExceeded`

## Naming Conventions

### Methods

| Context | Convention | Example |
|---------|-----------|---------|
| Builder configuration | Present tense, no "set"/"with" prefix | `.bold()`, `.fontSize(14)`, `.nameContains("Q1")` |
| Query filters | `.where(keyPath, label: value)` | `.where(\.status, equals: "Active")` |
| Terminal execution | Action verb | `.execute()`, `.apply()`, `.first()`, `.count()` |
| Async data operations | Verb phrase | `.values(range:)`, `.updateValues(range:values:)` |
| Factory methods | Return type name or description | `.format(_ range:) -> FormatBuilder`, `.query(_:in:) -> SheetQuery` |

### Parameters

| Convention | Example | Not |
|-----------|---------|-----|
| Full resource ID names | `spreadsheetId`, `sheetId`, `folderId` | `id`, `sid` |
| `range: SheetRange` | Always typed | Not `range: String` |
| Boolean defaults to `true` | `ascending: Bool = true`, `bold(_ enabled: Bool = true)` | |
| Closure parameters are descriptive | `builder`, `predicate`, `comparator` | `f`, `cb`, `block` |

### Types

| Convention | Example |
|-----------|---------|
| DSL operation structs are **PascalCase verbs/nouns** | `AddSheet`, `DeleteSheet`, `MergeCells`, `InsertDimension` |
| Model types are **nouns** | `Sheet`, `Spreadsheet`, `CellFormat`, `DriveFile` |
| Builder types end with `Builder` | `FormatBuilder`, `DriveListBuilder` |
| Enum option types end with `Option` | `ValueInputOption`, `ValueRenderOption` |

### File Organization

| Convention | Example |
|-----------|---------|
| MARK sections for logical grouping | `// MARK: - Batch Update`, `// MARK: - Execute` |
| Extensions over long monolithic structs | `public extension Spreadsheet { ... }` |
| One primary type per file | `FormatBuilder.swift`, `SheetQuery.swift` |
| Related small types can share a file | `SheetPrimitives.swift` has `SheetColumn` + `SheetRowIndex` |

## Concurrency Rules

### Sendable

Every public type must be `Sendable`. This is non-negotiable.

- Structs with all-Sendable stored properties: add `: Sendable` explicitly
- Closures stored in types: annotate `@Sendable`
- KeyPath parameters: constrain with `& Sendable`
- Generic parameters: add `& Sendable` (e.g., `T: SheetRowDecodable & Sendable`)

### Typed Throws

Every throwing function uses **typed throws**:

```swift
func values(range: SheetRange) async throws(SheetsError) -> [[String]]
```

Never use untyped `throws` in the public API. Internal helpers may use untyped throws only if the error is immediately caught and wrapped into `SheetsError`.

### Async/Await

All network operations are `async`. No completion handlers, no Combine publishers. The library is async/await native.

## Error Handling

`SheetsError` is the single error type. Every case has:
1. An associated value with context (where applicable)
2. A human-readable `errorDescription` via `LocalizedError`
3. Clear semantic meaning (not generic "something went wrong")

When adding new error cases:
- Prefer extending existing cases with richer associated values
- Only add a new case if the error is semantically distinct
- Always add the corresponding `errorDescription` in the `LocalizedError` extension

## Testing Standards

### Test Organization

```
Tests/SwiftySheetsTests/
  Infrastructure/     # MockURLSession, MockCredentials, TestConstants
  Unit/              # Pure unit tests (single component)
  Integration/       # Component integration tests (multiple components, mock network)
```

### Test Patterns

- Use `MockURLSession` with `queue(data:response:)` for multi-response scenarios
- Use `mockSession.mockData` / `mockSession.mockResponse` for single-response scenarios
- Every new public API method needs at least one test
- Every bug fix needs a regression test
- Value-type builders need copy-independence tests (modify derived, verify base unchanged)
- Error paths need explicit tests (not just happy path)

### Mock Conventions

```swift
private func setupMockSpreadsheet() {
    // Queue metadata response, then set up for value operations
}

private func mockValues(_ values: [[String]]) {
    // Queue a values response
}
```

## Macro Conventions

### @SheetRow

Generates `init(row:)`, `encodeRow()`, and memberwise `init` for structs with `@Column` annotations.

Rules:
- Generated `DateFormatter`/`ISO8601DateFormatter` statics use `nonisolated(unsafe)` for Sendable safety
- The macro declaration uses `names: named(init), named(encodeRow), arbitrary` to cover all generated members
- Column conversion helpers are shared in `ColumnHelpers.swift` (not duplicated per macro)

### #Range

Compile-time validated A1 notation. Produces a `SheetRange(...)` expression.

### @GenerateColumns

Generates `Column.A` through `Column.ZZ` (702 static properties) on the `Column` enum.

## Adding a New Batch Update Operation

Checklist for adding a new operation (e.g., `MergeCells`):

1. **Add the request model** in `BatchUpdateModels.swift`:
   ```swift
   public struct MergeCellsRequest: Encodable, Sendable { ... }
   ```

2. **Add the enum case** in `BatchUpdateRequest.Request`:
   ```swift
   case mergeCells(MergeCellsRequest)
   ```
   Update `CodingKeys` and `encode(to:)` accordingly.

3. **Create the DSL helper** in `DSLHelpers.swift`:
   ```swift
   public struct MergeCells: BatchRequestConvertible {
       public init(sheet: Sheet, range: SheetRange, type: MergeType = .mergeAll) { ... }
       public var request: BatchUpdateRequest.Request { ... }
   }
   ```

4. **Add convenience method** on `Spreadsheet` if it's commonly used standalone:
   ```swift
   func mergeCells(range: SheetRange, type: MergeType = .mergeAll) async throws(SheetsError) { ... }
   ```

5. **Write tests** — at minimum: success case, error case, builder integration test.

6. **Update `BatchUpdateBuilder.buildExpression`** if needed (usually not, since `BatchRequestConvertible` conformance handles it).

## Code Quality

- No warnings in `swift build`
- No force unwraps, force casts, or `try!`
- Keep public API surface minimal — internal by default, public only when needed
- Prefer computed properties over methods for simple derivations
- No abbreviations in public API names
- Every public type and method has a `///` doc comment
