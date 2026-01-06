# SheetQuery DSL Reference

SwiftySheets provides a powerful, type-safe Query DSL for filtering, sorting, and paginating spreadsheet data. This document covers all available operations.

## Quick Start

```swift
let results = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.isActive, equals: true)
    .where(\.score, greaterThan: 50)
    .sorted(by: \.score, ascending: false)
    .limit(10)
    .fetch()
```

## Filter Operations

### Equality

| Method | Description | Example |
|--------|-------------|---------|
| `where(_:equals:)` | Property equals value | `.where(\.status, equals: "Active")` |
| `where(_:notEquals:)` | Property doesn't equal value | `.where(\.status, notEquals: "Deleted")` |
| `where(_:isIn:)` | Property is in a set | `.where(\.status, isIn: ["Active", "Pending"])` |

### Comparison

| Method | Description | Example |
|--------|-------------|---------|
| `where(_:greaterThan:)` | Property > value | `.where(\.score, greaterThan: 50)` |
| `where(_:lessThan:)` | Property < value | `.where(\.score, lessThan: 100)` |
| `where(_:greaterThanOrEquals:)` | Property >= value | `.where(\.age, greaterThanOrEquals: 18)` |
| `where(_:lessThanOrEquals:)` | Property <= value | `.where(\.age, lessThanOrEquals: 65)` |
| `where(_:between:)` | Property in range (inclusive) | `.where(\.score, between: 50...100)` |

### String Matching

| Method | Description | Example |
|--------|-------------|---------|
| `where(_:contains:)` | String contains substring | `.where(\.name, contains: "Smith")` |
| `where(_:startsWith:)` | String starts with prefix | `.where(\.email, startsWith: "admin")` |
| `where(_:endsWith:)` | String ends with suffix | `.where(\.email, endsWith: "@company.com")` |

### Optional Checks

| Method | Description | Example |
|--------|-------------|---------|
| `whereNil(_:)` | Optional property is nil | `.whereNil(\.nickname)` |
| `whereNotNil(_:)` | Optional property is not nil | `.whereNotNil(\.manager)` |

### Custom Predicate

| Method | Description | Example |
|--------|-------------|---------|
| `filter(_:)` | Custom closure predicate | `.filter { $0.score > 50 && $0.isActive }` |

### OR Conditions

| Method | Description | Example |
|--------|-------------|---------|
| `or(_:)` | OR condition with nested filters | `.or { $0.where(\.isAdmin, equals: true) }` |

```swift
// Example: Active users OR admins
let results = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .where(\.isActive, equals: true)
    .or { $0.where(\.isAdmin, equals: true) }
    .fetch()
```

## Sort Operations

| Method | Description | Example |
|--------|-------------|---------|
| `sorted(by:ascending:)` | Primary sort | `.sorted(by: \.name)` |
| `thenSorted(by:ascending:)` | Secondary sort | `.thenSorted(by: \.createdAt)` |

```swift
// Sort by department, then by name within each department
let results = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .sorted(by: \.department)
    .thenSorted(by: \.name)
    .fetch()
```

## Pagination

| Method | Description | Example |
|--------|-------------|---------|
| `offset(_:)` | Skip N rows | `.offset(20)` |
| `limit(_:)` | Take N rows | `.limit(10)` |

```swift
// Get page 3 (rows 21-30)
let page3 = try await spreadsheet.query(User.self, in: #Range("A:D"))
    .sorted(by: \.createdAt, ascending: false)
    .offset(20)
    .limit(10)
    .fetch()
```

## Execution Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `execute()` | `[T]` | Execute query and return all matching rows |
| `fetch()` | `[T]` | Alias for `execute()` |
| `first()` | `T?` | Return first matching row or nil |
| `count()` | `Int` | Return count of matching rows |

## Execution Order

When you call `fetch()`, operations are applied in this order:

1. **Filter** - All `.where()` and `.filter()` predicates (AND'd together, with `.or()` branches)
2. **Sort** - Primary sort, then secondary sorts
3. **Offset** - Skip N rows
4. **Limit** - Take N rows

## Complete Example

```swift
// Complex query combining all features
let topActiveEngineers = try await spreadsheet.query(Employee.self, in: #Range("A:F"))
    // Filters (AND'd together)
    .where(\.department, equals: "Engineering")
    .where(\.status, notEquals: "Terminated")
    .where(\.salary, between: 80000...150000)
    .where(\.email, endsWith: "@company.com")
    .whereNotNil(\.manager)
    // OR condition
    .or { $0.where(\.isExecutive, equals: true) }
    // Sorting
    .sorted(by: \.performanceRating, ascending: false)
    .thenSorted(by: \.name)
    // Pagination
    .offset(0)
    .limit(25)
    // Execute
    .fetch()
```

## Performance Notes

- All filtering happens **client-side** after fetching data from Google Sheets
- Google Sheets API doesn't support server-side filtering, so large datasets will still be fetched entirely
- Use specific ranges (e.g., `A:D` instead of `A:Z`) to minimize data transfer
- The `.limit()` operation reduces memory usage after filtering

## Idempotency

- **Typed `.where()` methods are idempotent** - calling the same filter twice has no effect
- **Custom `.filter()` closures always add** - closures can't be compared for deduplication
- **Order of filters doesn't matter** - all filters are AND'd together
- **Sort order matters** - first `sorted()` is primary, subsequent `thenSorted()` are secondary
