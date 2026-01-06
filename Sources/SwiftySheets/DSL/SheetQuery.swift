import Foundation

struct UncheckedSendable<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - Query Builder

/// A fluent query builder for fetching and filtering typed rows.
/// ```swift
/// let employees = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
///     .filter { $0.salary > 50000 }
///     .sorted(by: \.name)
///     .fetch()
/// ```
public struct SheetQuery<T: SheetRowDecodable & Sendable>: Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    private let valueRenderOption: ValueRenderOption
    private let dateTimeRenderOption: DateRenderOption
    private let filterPredicate: @Sendable (T) -> Bool
    private let sortComparator: (@Sendable (T, T) -> Bool)?
    private let limitCount: Int?
    private let offsetCount: Int?
    
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
        self.filterPredicate = { _ in true }
        self.sortComparator = nil
        self.limitCount = nil
        self.offsetCount = nil
    }
    
    private init(
        spreadsheet: Spreadsheet,
        range: SheetRange,
        valueRenderOption: ValueRenderOption,
        dateTimeRenderOption: DateRenderOption,
        filterPredicate: @escaping @Sendable (T) -> Bool,
        sortComparator: (@Sendable (T, T) -> Bool)?,
        limitCount: Int?,
        offsetCount: Int?
    ) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
        self.filterPredicate = filterPredicate
        self.sortComparator = sortComparator
        self.limitCount = limitCount
        self.offsetCount = offsetCount
    }
    
    // MARK: - Filter
    
    /// Filter rows using a predicate closure.
    /// ```swift
    /// .filter { $0.salary > 50000 }
    /// ```
    public func filter(_ predicate: @escaping @Sendable (T) -> Bool) -> SheetQuery<T> {
        let currentPredicate = self.filterPredicate
        return SheetQuery(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption,
            filterPredicate: { currentPredicate($0) && predicate($0) },
            sortComparator: sortComparator,
            limitCount: limitCount,
            offsetCount: offsetCount
        )
    }
    
    /// Filter rows where a property equals a value.
    /// ```swift
    /// .where(\.department, equals: "Engineering")
    /// ```
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V>, equals value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        return filter { $0[keyPath: safeKeyPath.value] == value }
    }
    
    /// Filter rows where a property is in a set of values.
    /// ```swift
    /// .where(\.status, isIn: ["Active", "Pending"])
    /// ```
    public func `where`<V: Equatable & Sendable>(_ keyPath: KeyPath<T, V>, isIn values: Set<V>) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        return filter { values.contains($0[keyPath: safeKeyPath.value]) }
    }
    
    /// Filter rows where a comparable property is greater than a value.
    /// ```swift
    /// .where(\.salary, greaterThan: 50000)
    /// ```
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, greaterThan value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        return filter { $0[keyPath: safeKeyPath.value] > value }
    }
    
    /// Filter rows where a comparable property is less than a value.
    public func `where`<V: Comparable & Sendable>(_ keyPath: KeyPath<T, V>, lessThan value: V) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        return filter { $0[keyPath: safeKeyPath.value] < value }
    }
    
    /// Filter rows where a string property contains a substring.
    /// ```swift
    /// .where(\.name, contains: "Smith")
    /// ```
    public func `where`(_ keyPath: KeyPath<T, String>, contains substring: String) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        return filter { $0[keyPath: safeKeyPath.value].contains(substring) }
    }
    
    // MARK: - Sort
    
    /// Sort rows by a comparable property.
    /// ```swift
    /// .sorted(by: \.name)
    /// .sorted(by: \.salary, ascending: false)
    /// ```
    public func sorted<V: Comparable & Sendable>(by keyPath: KeyPath<T, V>, ascending: Bool = true) -> SheetQuery<T> {
        let safeKeyPath = UncheckedSendable(keyPath)
        let comparator: @Sendable (T, T) -> Bool = { lhs, rhs in
            let l = lhs[keyPath: safeKeyPath.value]
            let r = rhs[keyPath: safeKeyPath.value]
            return ascending ? l < r : l > r
        }
        
        return SheetQuery(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption,
            filterPredicate: filterPredicate,
            sortComparator: comparator,
            limitCount: limitCount,
            offsetCount: offsetCount
        )
    }
    
    // MARK: - Limit
    
    /// Limit the number of results.
    /// ```swift
    /// .limit(10)
    /// ```
    public func limit(_ count: Int) -> SheetQuery<T> {
        SheetQuery(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption,
            filterPredicate: filterPredicate,
            sortComparator: sortComparator,
            limitCount: count,
            offsetCount: offsetCount
        )
    }
    
    /// Skip a number of rows (for pagination).
    /// ```swift
    /// .offset(20).limit(10)  // Page 3
    /// ```
    public func offset(_ count: Int) -> SheetQuery<T> {
        SheetQuery(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption,
            filterPredicate: filterPredicate,
            sortComparator: sortComparator,
            limitCount: limitCount,
            offsetCount: count
        )
    }
    
    // MARK: - Execute
    
    /// Fetch all rows matching the query.
    public func fetch() async throws(SheetsError) -> [T] {
        // Get all typed values
        var results = try await spreadsheet.values(
            range: range,
            type: T.self,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
        
        // Apply filter
        results = results.filter(filterPredicate)
        
        // Apply sort if specified
        if let comparator = sortComparator {
            results.sort(by: comparator)
        }
        
        // Apply offset
        if let offset = offsetCount {
            results = Array(results.dropFirst(offset))
        }
        
        // Apply limit
        if let limit = limitCount {
            results = Array(results.prefix(limit))
        }
        
        return results
    }
    
    /// Fetch the first row matching the query.
    public func first() async throws(SheetsError) -> T? {
        try await limit(1).fetch().first
    }
    
    /// Count rows matching the query.
    public func count() async throws(SheetsError) -> Int {
        try await fetch().count
    }
}
