import Foundation

/// Internal: A filter with a key for deduplication
private struct KeyedFilter<T: Sendable>: Sendable {
    let key: String?  // nil = custom filter (no deduplication)
    let predicate: @Sendable (T) -> Bool
}

// MARK: - Query Builder

/// A fluent query builder for fetching and filtering typed rows.
/// Uses copy-on-return semantics for full value-type safety and `Sendable` conformance
/// with no data races. All builder methods return a modified copy, leaving the original
/// query unchanged.
/// - Typed `.where()` methods are idempotent (duplicates ignored)
/// - Custom `.filter()` closures always add
/// - Sort operations chain correctly
/// ```swift
/// let employees = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
///     .filter { $0.salary > 50000 }
///     .sorted(by: \.name)
///     .execute()
/// ```
public struct SheetQuery<T: SheetRowDecodable & Sendable>: Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    private let valueRenderOption: ValueRenderOption
    private let dateTimeRenderOption: DateRenderOption

    // Accumulated state — copied on every builder call
    private var filters: [KeyedFilter<T>] = []
    private var filterKeys: Set<String> = []  // Track added filter keys for deduplication
    private var orBranches: [[@Sendable (T) -> Bool]] = []
    private var sortComparators: [@Sendable (T, T) -> Bool] = []
    private var _limitCount: Int?
    private var _offsetCount: Int?

    init(
        spreadsheet: Spreadsheet,
        range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
    }

    // MARK: - Internal Filter Helpers

    /// Add a keyed filter (for deduplication). Silently ignores duplicate keys.
    private mutating func addFilter(key: String, predicate: @escaping @Sendable (T) -> Bool) {
        guard !filterKeys.contains(key) else { return }
        filterKeys.insert(key)
        filters.append(KeyedFilter(key: key, predicate: predicate))
    }

    /// Add a custom filter (no deduplication).
    private mutating func addCustomFilter(predicate: @escaping @Sendable (T) -> Bool) {
        filters.append(KeyedFilter(key: nil, predicate: predicate))
    }

    // MARK: - Filter

    /// Filter rows using a predicate closure.
    /// Note: Custom filters are always added (no deduplication possible).
    /// ```swift
    /// .filter { $0.salary > 50000 }
    /// ```
    public func filter(_ predicate: @escaping @Sendable (T) -> Bool) -> SheetQuery<T> {
        var copy = self
        copy.addCustomFilter(predicate: predicate)
        return copy
    }

    /// Filter rows where a property equals a value.
    /// ```swift
    /// .where(\.department, equals: "Engineering")
    /// ```
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, equals value: V) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "equals:\(keyPath):\(value)") { $0[keyPath: keyPath] == value }
        return copy
    }

    /// Filter rows where a property does not equal a value.
    /// ```swift
    /// .where(\.status, notEquals: "Deleted")
    /// ```
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, notEquals value: V) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "notEquals:\(keyPath):\(value)") { $0[keyPath: keyPath] != value }
        return copy
    }

    /// Filter rows where a property is in a set of values.
    /// ```swift
    /// .where(\.status, isIn: ["Active", "Pending"])
    /// ```
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, isIn values: Set<V>) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "isIn:\(keyPath):\(values.hashValue)") { values.contains($0[keyPath: keyPath]) }
        return copy
    }

    /// Filter rows where a comparable property is greater than a value.
    /// ```swift
    /// .where(\.salary, greaterThan: 50000)
    /// ```
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, greaterThan value: V) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "greaterThan:\(keyPath):\(value)") { $0[keyPath: keyPath] > value }
        return copy
    }

    /// Filter rows where a comparable property is less than a value.
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, lessThan value: V) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "lessThan:\(keyPath):\(value)") { $0[keyPath: keyPath] < value }
        return copy
    }

    /// Filter rows where a comparable property is greater than or equal to a value.
    /// ```swift
    /// .where(\.age, greaterThanOrEquals: 18)
    /// ```
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, greaterThanOrEquals value: V) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "greaterThanOrEquals:\(keyPath):\(value)") { $0[keyPath: keyPath] >= value }
        return copy
    }

    /// Filter rows where a comparable property is less than or equal to a value.
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, lessThanOrEquals value: V) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "lessThanOrEquals:\(keyPath):\(value)") { $0[keyPath: keyPath] <= value }
        return copy
    }

    /// Filter rows where a comparable property is between two values (inclusive).
    /// ```swift
    /// .where(\.score, between: 50...100)
    /// ```
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V> & Sendable, between range: ClosedRange<V>) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "between:\(keyPath):\(range)") { range.contains($0[keyPath: keyPath]) }
        return copy
    }

    /// Filter rows where a string property contains a substring.
    /// ```swift
    /// .where(\.name, contains: "Smith")
    /// ```
    public func `where`(_ keyPath: KeyPath<T, String> & Sendable, contains substring: String) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "contains:\(keyPath):\(substring)") { $0[keyPath: keyPath].contains(substring) }
        return copy
    }

    /// Filter rows where a string property starts with a prefix.
    /// ```swift
    /// .where(\.email, startsWith: "admin")
    /// ```
    public func `where`(_ keyPath: KeyPath<T, String> & Sendable, startsWith prefix: String) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "startsWith:\(keyPath):\(prefix)") { $0[keyPath: keyPath].hasPrefix(prefix) }
        return copy
    }

    /// Filter rows where a string property ends with a suffix.
    /// ```swift
    /// .where(\.email, endsWith: "@company.com")
    /// ```
    public func `where`(_ keyPath: KeyPath<T, String> & Sendable, endsWith suffix: String) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "endsWith:\(keyPath):\(suffix)") { $0[keyPath: keyPath].hasSuffix(suffix) }
        return copy
    }

    /// Filter rows where an optional property is nil.
    /// ```swift
    /// .whereNil(\.nickname)
    /// ```
    public func whereNil<V: Sendable>(_ keyPath: KeyPath<T, V?> & Sendable) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "isNil:\(keyPath)") { $0[keyPath: keyPath] == nil }
        return copy
    }

    /// Filter rows where an optional property is not nil.
    /// ```swift
    /// .whereNotNil(\.nickname)
    /// ```
    public func whereNotNil<V: Sendable>(_ keyPath: KeyPath<T, V?> & Sendable) -> SheetQuery<T> {
        var copy = self
        copy.addFilter(key: "isNotNil:\(keyPath)") { $0[keyPath: keyPath] != nil }
        return copy
    }

    /// Add an OR branch to the query. An item passes if it matches the AND filters
    /// AND at least one OR branch. Within an OR branch, multiple conditions are AND'd together.
    ///
    /// Example: items where `dept == "Eng"` AND (`status == "Active"` OR `status == "Pending"`):
    /// ```swift
    /// .where(\.dept, equals: "Eng")
    /// .or { $0.where(\.status, equals: "Active") }
    /// .or { $0.where(\.status, equals: "Pending") }
    /// ```
    public func or(_ builder: @Sendable (SheetQuery<T>) -> SheetQuery<T>) -> SheetQuery<T> {
        // Create a fresh query to capture only the OR branch predicates
        let freshQuery = SheetQuery<T>(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
        let orQuery = builder(freshQuery)
        let branchPredicates = orQuery.filters.map { $0.predicate }

        var copy = self
        if !branchPredicates.isEmpty {
            copy.orBranches.append(branchPredicates)
        }
        return copy
    }

    // MARK: - Sort

    /// Sort rows by a comparable property.
    /// Multiple calls chain as primary, secondary, etc. sort keys.
    /// ```swift
    /// .sorted(by: \.department)
    /// .sorted(by: \.name)  // secondary sort
    /// ```
    public func sorted<V: Comparable & Sendable>(by keyPath: KeyPath<T, V> & Sendable, ascending: Bool = true) -> SheetQuery<T> {
        let comparator: @Sendable (T, T) -> Bool = { lhs, rhs in
            let l = lhs[keyPath: keyPath]
            let r = rhs[keyPath: keyPath]
            return ascending ? l < r : l > r
        }
        var copy = self
        copy.sortComparators.append(comparator)
        return copy
    }

    // MARK: - Pagination

    /// Limit the number of results.
    /// ```swift
    /// .limit(10)
    /// ```
    public func limit(_ count: Int) -> SheetQuery<T> {
        var copy = self
        copy._limitCount = count
        return copy
    }

    /// Skip a number of rows (for pagination).
    /// ```swift
    /// .offset(20).limit(10)  // Page 3
    /// ```
    public func offset(_ count: Int) -> SheetQuery<T> {
        var copy = self
        copy._offsetCount = count
        return copy
    }

    // MARK: - Execute

    /// Execute the query and fetch all matching rows.
    public func execute() async throws(SheetsError) -> [T] {
        // Get all typed values
        var results = try await spreadsheet.values(
            range: range,
            type: T.self,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )

        // Apply AND filters
        if !filters.isEmpty {
            results = results.filter { item in
                filters.allSatisfy { $0.predicate(item) }
            }
        }

        // Apply OR branches: item must pass at least one OR branch
        // (each branch is a set of AND'd predicates)
        if !orBranches.isEmpty {
            results = results.filter { item in
                orBranches.contains { branch in
                    branch.allSatisfy { predicate in predicate(item) }
                }
            }
        }

        // Apply sort (chain of comparators)
        if !sortComparators.isEmpty {
            results.sort { lhs, rhs in
                for comparator in sortComparators {
                    if comparator(lhs, rhs) { return true }
                    if comparator(rhs, lhs) { return false }
                }
                return false // Equal
            }
        }

        // Apply offset
        if let offset = _offsetCount {
            results = Array(results.dropFirst(offset))
        }

        // Apply limit
        if let limit = _limitCount {
            results = Array(results.prefix(limit))
        }

        return results
    }

    /// Fetch the first row matching the query.
    /// Creates an internal copy with `limit(1)` before executing so that the
    /// caller's query is not mutated and sorting/filtering can stop early.
    public func first() async throws(SheetsError) -> T? {
        var limited = self
        limited._limitCount = 1
        return try await limited.execute().first
    }

    /// Count rows matching the query.
    public func count() async throws(SheetsError) -> Int {
        try await execute().count
    }
}
