import Foundation

struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

/// Internal: A filter with a key for deduplication
private struct KeyedFilter<T>: @unchecked Sendable {
    let key: String?  // nil = custom filter (no deduplication)
    let predicate: @Sendable (T) -> Bool
}

// MARK: - Query Builder

/// A fluent query builder for fetching and filtering typed rows.
/// Uses mutable state internally for efficiency, executes on fetch().
/// - Typed `.where()` methods are idempotent (duplicates ignored)
/// - Custom `.filter()` closures always add
/// - Sort operations chain correctly
/// ```swift
/// let employees = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
///     .filter { $0.salary > 50000 }
///     .sorted(by: \.name)
///     .execute()
/// ```
public final class SheetQuery<T: SheetRowDecodable & Sendable>: @unchecked Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    private let valueRenderOption: ValueRenderOption
    private let dateTimeRenderOption: DateRenderOption
    
    // Mutable state - accumulated during chaining
    private var filters: [KeyedFilter<T>] = []
    private var filterKeys: Set<String> = []  // Track added filter keys
    private var orPredicates: [@Sendable (T) -> Bool] = []
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
    
    /// Add a keyed filter (for deduplication)
    private func addFilter(key: String, predicate: @escaping @Sendable (T) -> Bool) {
        guard !filterKeys.contains(key) else { return }  // Ignore duplicates
        filterKeys.insert(key)
        filters.append(KeyedFilter(key: key, predicate: predicate))
    }
    
    /// Add a custom filter (no deduplication)
    private func addCustomFilter(predicate: @escaping @Sendable (T) -> Bool) {
        filters.append(KeyedFilter(key: nil, predicate: predicate))
    }
    
    // MARK: - Filter
    
    /// Filter rows using a predicate closure.
    /// Note: Custom filters are always added (no deduplication possible).
    /// ```swift
    /// .filter { $0.salary > 50000 }
    /// ```
    @discardableResult
    public func filter(_ predicate: @escaping @Sendable (T) -> Bool) -> SheetQuery<T> {
        addCustomFilter(predicate: predicate)
        return self
    }
    
    /// Filter rows where a property equals a value.
    /// ```swift
    /// .where(\.department, equals: "Engineering")
    /// ```
    @discardableResult
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V>, equals value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "equals:\(keyPath):\(value)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] == value }
        return self
    }
    
    /// Filter rows where a property does not equal a value.
    /// ```swift
    /// .where(\.status, notEquals: "Deleted")
    /// ```
    @discardableResult
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V>, notEquals value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "notEquals:\(keyPath):\(value)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] != value }
        return self
    }
    
    /// Filter rows where a property is in a set of values.
    /// ```swift
    /// .where(\.status, isIn: ["Active", "Pending"])
    /// ```
    @discardableResult
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V>, isIn values: Set<V>) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "isIn:\(keyPath):\(values.hashValue)"
        addFilter(key: key) { values.contains($0[keyPath: safeKeyPath.value]) }
        return self
    }
    
    /// Filter rows where a comparable property is greater than a value.
    /// ```swift
    /// .where(\.salary, greaterThan: 50000)
    /// ```
    @discardableResult
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, greaterThan value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "greaterThan:\(keyPath):\(value)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] > value }
        return self
    }
    
    /// Filter rows where a comparable property is less than a value.
    @discardableResult
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, lessThan value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "lessThan:\(keyPath):\(value)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] < value }
        return self
    }
    
    /// Filter rows where a comparable property is greater than or equal to a value.
    /// ```swift
    /// .where(\.age, greaterThanOrEquals: 18)
    /// ```
    @discardableResult
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, greaterThanOrEquals value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "greaterThanOrEquals:\(keyPath):\(value)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] >= value }
        return self
    }
    
    /// Filter rows where a comparable property is less than or equal to a value.
    @discardableResult
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, lessThanOrEquals value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "lessThanOrEquals:\(keyPath):\(value)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] <= value }
        return self
    }
    
    /// Filter rows where a comparable property is between two values (inclusive).
    /// ```swift
    /// .where(\.score, between: 50...100)
    /// ```
    @discardableResult
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, between range: ClosedRange<V>) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "between:\(keyPath):\(range)"
        addFilter(key: key) { range.contains($0[keyPath: safeKeyPath.value]) }
        return self
    }
    
    /// Filter rows where a string property contains a substring.
    /// ```swift
    /// .where(\.name, contains: "Smith")
    /// ```
    @discardableResult
    public func `where`(_ keyPath: KeyPath<T, String>, contains substring: String) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "contains:\(keyPath):\(substring)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value].contains(substring) }
        return self
    }
    
    /// Filter rows where a string property starts with a prefix.
    /// ```swift
    /// .where(\.email, startsWith: "admin")
    /// ```
    @discardableResult
    public func `where`(_ keyPath: KeyPath<T, String>, startsWith prefix: String) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "startsWith:\(keyPath):\(prefix)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value].hasPrefix(prefix) }
        return self
    }
    
    /// Filter rows where a string property ends with a suffix.
    /// ```swift
    /// .where(\.email, endsWith: "@company.com")
    /// ```
    @discardableResult
    public func `where`(_ keyPath: KeyPath<T, String>, endsWith suffix: String) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "endsWith:\(keyPath):\(suffix)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value].hasSuffix(suffix) }
        return self
    }
    
    /// Filter rows where an optional property is nil.
    /// ```swift
    /// .whereNil(\.nickname)
    /// ```
    @discardableResult
    public func whereNil<V: Sendable>(_ keyPath: KeyPath<T, V?>) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "isNil:\(keyPath)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] == nil }
        return self
    }
    
    /// Filter rows where an optional property is not nil.
    /// ```swift
    /// .whereNotNil(\.nickname)
    /// ```
    @discardableResult
    public func whereNotNil<V: Sendable>(_ keyPath: KeyPath<T, V?>) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let key = "isNotNil:\(keyPath)"
        addFilter(key: key) { $0[keyPath: safeKeyPath.value] != nil }
        return self
    }
    
    /// Add an OR condition to the query.
    /// ```swift
    /// .or { $0.where(\.status, equals: "Active") }
    /// ```
    @discardableResult
    public func or(_ builder: (SheetQuery<T>) -> SheetQuery<T>) -> SheetQuery<T> {
        // Create a fresh query to capture the OR branch predicates
        let freshQuery = SheetQuery<T>(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
        let orQuery = builder(freshQuery)
        
        // Combine the OR branch filters into one predicate
        let orBranchFilters = orQuery.filters
        if !orBranchFilters.isEmpty {
            let combinedOrPredicate: @Sendable (T) -> Bool = { item in
                orBranchFilters.allSatisfy { $0.predicate(item) }
            }
            orPredicates.append(combinedOrPredicate)
        }
        return self
    }
    
    // MARK: - Sort
    
    /// Sort rows by a comparable property.
    /// ```swift
    /// .sorted(by: \.name)
    /// .sorted(by: \.salary, ascending: false)
    /// ```
    @discardableResult
    public func sorted<V: Comparable & Sendable>(by keyPath: KeyPath<T, V>, ascending: Bool = true) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let comparator: @Sendable (T, T) -> Bool = { lhs, rhs in
            let l = lhs[keyPath: safeKeyPath.value]
            let r = rhs[keyPath: safeKeyPath.value]
            return ascending ? l < r : l > r
        }
        sortComparators.append(comparator)
        return self
    }
    
    /// Add a secondary sort after the primary sort.
    /// ```swift
    /// .sorted(by: \.department).thenSorted(by: \.name)
    /// ```
    @discardableResult
    public func thenSorted<V: Comparable & Sendable>(by keyPath: KeyPath<T, V>, ascending: Bool = true) -> SheetQuery<T> {
        // thenSorted just adds another comparator to the chain
        return sorted(by: keyPath, ascending: ascending)
    }
    
    // MARK: - Pagination
    
    /// Limit the number of results.
    /// ```swift
    /// .limit(10)
    /// ```
    @discardableResult
    public func limit(_ count: Int) -> SheetQuery<T> {
        _limitCount = count
        return self
    }
    
    /// Skip a number of rows (for pagination).
    /// ```swift
    /// .offset(20).limit(10)  // Page 3
    /// ```
    @discardableResult
    public func offset(_ count: Int) -> SheetQuery<T> {
        _offsetCount = count
        return self
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
        
        // Apply OR predicates (any OR branch passes)
        if !orPredicates.isEmpty {
            results = results.filter { item in
                // Item passes if it passes AND filters OR any OR branch
                orPredicates.contains { $0(item) }
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
    
    /// Alias for execute() - fetch all rows matching the query.
    public func fetch() async throws(SheetsError) -> [T] {
        try await execute()
    }
    
    /// Fetch the first row matching the query.
    public func first() async throws(SheetsError) -> T? {
        _limitCount = 1
        return try await execute().first
    }
    
    /// Count rows matching the query.
    public func count() async throws(SheetsError) -> Int {
        try await execute().count
    }
}
