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
public struct SheetQuery<T: SheetRowDecodable & Sendable>: @unchecked Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    private let valueRenderOption: ValueRenderOption
    private let dateTimeRenderOption: DateRenderOption
    private let filterPredicate: @Sendable (T) -> Bool
    private let sortKeyPath: UncheckedSendable<AnyKeyPath>?
    private let sortAscending: Bool
    private let limitCount: Int?
    
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
        self.sortKeyPath = nil
        self.sortAscending = true
        self.limitCount = nil
    }
    
    private init(
        spreadsheet: Spreadsheet,
        range: SheetRange,
        valueRenderOption: ValueRenderOption,
        dateTimeRenderOption: DateRenderOption,
        filterPredicate: @escaping @Sendable (T) -> Bool,
        sortKeyPath: UncheckedSendable<AnyKeyPath>?,
        sortAscending: Bool,
        limitCount: Int?
    ) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
        self.filterPredicate = filterPredicate
        self.sortKeyPath = sortKeyPath
        self.sortAscending = sortAscending
        self.limitCount = limitCount
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
            sortKeyPath: sortKeyPath,
            sortAscending: sortAscending,
            limitCount: limitCount
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
        SheetQuery(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption,
            filterPredicate: filterPredicate,
            sortKeyPath: UncheckedSendable(keyPath),
            sortAscending: ascending,
            limitCount: limitCount
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
            sortKeyPath: sortKeyPath,
            sortAscending: sortAscending,
            limitCount: count
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
        if let keyPathWrapper = sortKeyPath {
            results = sortResults(results, by: keyPathWrapper.value, ascending: sortAscending)
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
    
    // Helper for type-erased sorting
    private func sortResults(_ results: [T], by keyPath: AnyKeyPath, ascending: Bool) -> [T] {
        // Type-erased sorting - we lose compile-time safety here but gain flexibility
        results.sorted { lhs, rhs in
            guard let lhsValue = lhs[keyPath: keyPath] as? any Comparable,
                  let rhsValue = rhs[keyPath: keyPath] as? any Comparable else {
                return false
            }
            return compareAny(lhsValue, rhsValue, ascending: ascending)
        }
    }
    
    private func compareAny(_ lhs: any Comparable, _ rhs: any Comparable, ascending: Bool) -> Bool {
        // Use string representation for type-erased comparison
        let lhsStr = String(describing: lhs)
        let rhsStr = String(describing: rhs)
        return ascending ? lhsStr < rhsStr : lhsStr > rhsStr
    }
}
