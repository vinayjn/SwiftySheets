import Foundation

public struct Spreadsheet: Sendable {
    public struct Metadata: Codable, Sendable {
        public let spreadsheetId: String
        public let properties: Properties
        public let sheets: [Sheet]

        public struct Properties: Codable, Sendable {
            public let title: String
        }
    }

    private let client: Client
    private let id: String
    public private(set) var metadata: Metadata

    init(client: Client, id: String) async throws(SheetsError) {
        self.client = client
        self.id = id
        metadata = try await Self.fetchMetadata(id: id, client: client)
    }
    
    init(client: Client, metadata: Metadata) {
        self.client = client
        self.id = metadata.spreadsheetId
        self.metadata = metadata
    }
}

private extension Spreadsheet {
    static func fetchMetadata(id: String, client: Client) async throws(SheetsError) -> Metadata {
        guard let request = try? Endpoint.spreadsheet(id: id).request() else {
            throw .invalidRequest
        }
        return try await client.makeRequest(request)
    }
}

public extension Spreadsheet {
    func values(
        range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) async throws(SheetsError) -> [[String]] {
        guard let request = try? Endpoint.values(
            spreadsheetId: id,
            range: range.description,
            valueRenderOption: valueRenderOption.rawValue,
            dateTimeRenderOption: dateTimeRenderOption.rawValue
        ).request() else {
            throw .invalidRequest
        }
        let response: ValueRange = try await client.makeRequest(request)
        return response.values
    }

    mutating func refreshMetadata() async throws(SheetsError) {
        metadata = try await Self.fetchMetadata(id: id, client: client)
    }

    func sheets(afterRefreshingMetadata _: Bool = false) -> [Sheet] {
        metadata.sheets
    }

    func sheet(named name: String) throws(SheetsError) -> Sheet {
        guard let sheet = sheets().first(where: { $0.properties.title == name }) else {
            throw .sheetNotFound(message: "Name: \(name)")
        }
        return sheet
    }
    
    @discardableResult
    func updateValues(
        range: SheetRange,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws(SheetsError) -> UpdateValuesResponse {
        try await client.updateValues(
            spreadsheetId: id,
            range: range.description,
            values: values,
            valueInputOption: valueInputOption
        )
    }
    
    @discardableResult
    func appendValues(
        range: SheetRange,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws(SheetsError) -> UpdateValuesResponse {
        try await client.appendValues(
            spreadsheetId: id,
            range: range.description,
            values: values,
            valueInputOption: valueInputOption
        )
    }
    
    // MARK: - Batch Update
    
    @discardableResult
    func batchUpdate(requests: [BatchUpdateRequest.Request]) async throws(SheetsError) -> BatchUpdateResponse {
        return try await client.batchUpdate(spreadsheetId: id, requests: requests)
    }
    
    @discardableResult
    func batchUpdate(@BatchUpdateBuilder _ builder: @Sendable () -> [BatchUpdateRequest.Request]) async throws(SheetsError) -> BatchUpdateResponse {
        try await batchUpdate(requests: builder())
    }
    
    func addSheet(title: String, rowCount: Int = 1000, columnCount: Int = 26) async throws(SheetsError) {
        let request = AddSheet(title, gridProperties: Sheet.GridProperties(rowCount: rowCount, columnCount: columnCount))
        try await batchUpdate(requests: [request.request])
    }
    
    // MARK: - Generic Codable Helpers
    
    func values<T: SheetRowDecodable>(
        range: SheetRange,
        type: T.Type,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) async throws(SheetsError) -> [T] {
        let rawValues = try await values(
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
        do {
            return try rawValues.map { try T(row: $0) }
        } catch {
            throw .invalidResponse(status: 0)
        }
    }
    
    @discardableResult
    func updateValues<T: SheetRowEncodable>(
        range: SheetRange,
        values: [T],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws(SheetsError) -> UpdateValuesResponse {
        let encodedValues: [[String]]
        do {
            encodedValues = try values.map { try $0.encodeRow() }
        } catch {
            throw .invalidRequest
        }
        return try await updateValues(
            range: range,
            values: encodedValues,
            valueInputOption: valueInputOption
        )
    }
    
    @discardableResult
    func appendValues<T: SheetRowEncodable>(
        range: SheetRange,
        values: [T],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws(SheetsError) -> UpdateValuesResponse {
        let encodedValues: [[String]]
        do {
            encodedValues = try values.map { try $0.encodeRow() }
        } catch {
            throw .invalidRequest
        }
        return try await appendValues(
            range: range,
            values: encodedValues,
            valueInputOption: valueInputOption
        )
    }
    
    // MARK: - Streaming (AsyncSequence)
    
    /// Stream rows from a range as an AsyncSequence.
    /// ```swift
    /// for try await row in spreadsheet.rows(in: #Range("A:Z")) {
    ///     print(row)
    /// }
    /// ```
    func rows(
        in range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) -> RowAsyncSequence {
        RowAsyncSequence(
            spreadsheet: self,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
    }
    
    /// Stream typed rows from a range as an AsyncSequence.
    /// ```swift
    /// for try await employee in spreadsheet.stream(Employee.self, in: #Range("A:D")) {
    ///     print(employee.name)
    /// }
    /// ```
    func stream<T: SheetRowDecodable & Sendable>(
        _ type: T.Type,
        in range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) -> TypedRowAsyncSequence<T> {
        TypedRowAsyncSequence(
            spreadsheet: self,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
    }
    
    // MARK: - Query DSL
    
    /// Create a fluent query for typed rows with filtering and sorting.
    /// ```swift
    /// let employees = try await spreadsheet.query(Employee.self, in: #Range("A:D"))
    ///     .where(\.department, equals: "Engineering")
    ///     .where(\.salary, greaterThan: 50000)
    ///     .sorted(by: \.name)
    ///     .limit(10)
    ///     .fetch()
    /// ```
    func query<T: SheetRowDecodable & Sendable>(
        _ type: T.Type,
        in range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) -> SheetQuery<T> {
        SheetQuery(
            spreadsheet: self,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
    }
    
    // MARK: - Advanced Operations
    
    func format(range: SheetRange, format: CellFormat) async throws(SheetsError) {
        let sheet = try resolveSheet(for: range)
        let request = FormatCells(sheet: sheet, range: range, format: format)
        try await batchUpdate(requests: [request.request])
    }
    
    /// Format cells using a declarative builder syntax:
    /// ```
    /// try await spreadsheet.format(#Range("A1:B10")) {
    ///     BackgroundColor(.blue)
    ///     Bold()
    ///     FontSize(14)
    /// }
    /// ```
    func format(
        _ range: SheetRange,
        @CellFormatBuilder _ builder: () -> CellFormat
    ) async throws(SheetsError) {
        try await format(range: range, format: builder())
    }
    
    func sort(range: SheetRange, column: Int, ascending: Bool = true) async throws(SheetsError) {
        let sheet = try resolveSheet(for: range)
        let request = SortRange(sheet: sheet, range: range, column: column, ascending: ascending)
        try await batchUpdate(requests: [request.request])
    }
    
    @discardableResult
    func clearValues(range: SheetRange) async throws(SheetsError) -> ClearValuesResponse {
        try await client.clearValues(spreadsheetId: id, range: range.description)
    }
    
    // MARK: - Developer Experience
    
    func cell(_ range: SheetRange) async throws(SheetsError) -> String? {
        let values = try await self.values(range: range)
        return values.first?.first
    }
    
    func cell(row: Int, column: Int) async throws(SheetsError) -> String? {
        let colStr = SheetRange.indexToColumn(column - 1)
        guard let col = try? SheetColumn(colStr as String),
              let rowIdx = try? SheetRowIndex(row as Int) else {
            throw .invalidRange(message: "Invalid row/column: \(row), \(column)")
        }
        let r = SheetRange.root().from(col: col, row: rowIdx)
        return try await cell(r)
    }
    
    func cell(sheet: String, row: Int, column: Int) async throws(SheetsError) -> String? {
        let colStr = SheetRange.indexToColumn(column - 1)
        guard let col = try? SheetColumn(colStr as String),
              let rowIdx = try? SheetRowIndex(row as Int) else {
            throw .invalidRange(message: "Invalid row/column: \(row), \(column)")
        }
        let r = SheetRange.root(sheet).from(col: col, row: rowIdx)
        return try await cell(r)
    }

    func resize(sheetId: Int, rows: Int, columns: Int) async throws(SheetsError) {
        let request = ResizeSheet(
            sheet: Sheet(properties: Sheet.SheetProperties(sheetId: sheetId, title: "", index: 0, gridProperties: Sheet.GridProperties(rowCount: 0, columnCount: 0))),
            rows: rows,
            columns: columns
        )
        try await batchUpdate(requests: [request.request])
    }

    private func resolveSheet(for range: SheetRange) throws(SheetsError) -> Sheet {
        if let name = range.sheetName {
            return try sheet(named: name)
        } else {
            guard let first = metadata.sheets.first else {
                throw .spreadsheetNotFound(message: "No sheets found")
            }
            return first
        }
    }
}

// MARK: - Subscript Syntax (Convenience API)

/// Provides convenient subscript access to cells.
/// For type-safe operations, use the explicit method APIs.
public extension Spreadsheet {
    
    /// Access a single cell value using A1 notation: `spreadsheet["A1"]`
    subscript(_ a1Notation: String) -> CellAccessor {
        CellAccessor(spreadsheet: self, notation: a1Notation)
    }
    
    /// Access a single cell by row and column (1-indexed): `spreadsheet[1, 1]`
    subscript(_ row: Int, _ column: Int) -> CellAccessor {
        let colStr = SheetRange.indexToColumn(column - 1)
        return CellAccessor(spreadsheet: self, notation: "\(colStr)\(row)")
    }
    
    /// Access cells with a validated SheetRange: `spreadsheet[#Range("A1:B10")]`
    subscript(_ range: SheetRange) -> RangeAccessor {
        RangeAccessor(spreadsheet: self, range: range)
    }
}

/// Accessor for single cell operations via subscript
public struct CellAccessor: Sendable {
    private let spreadsheet: Spreadsheet
    private let notation: String
    
    init(spreadsheet: Spreadsheet, notation: String) {
        self.spreadsheet = spreadsheet
        self.notation = notation
    }
    
    /// Get the cell value
    public func get() async throws(SheetsError) -> String? {
        guard let range = try? SheetRange(parsing: notation) else {
            throw .invalidRange(message: "Invalid A1 notation: \(notation)")
        }
        return try await spreadsheet.cell(range)
    }
    
    /// Set the cell value
    public func set(_ value: String) async throws(SheetsError) {
        guard let range = try? SheetRange(parsing: notation) else {
            throw .invalidRange(message: "Invalid A1 notation: \(notation)")
        }
        try await spreadsheet.updateValues(range: range, values: [[value]])
    }
}

/// Accessor for range operations via subscript
public struct RangeAccessor: Sendable {
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    
    init(spreadsheet: Spreadsheet, range: SheetRange) {
        self.spreadsheet = spreadsheet
        self.range = range
    }
    
    /// Get all values in the range
    public func get() async throws(SheetsError) -> [[String]] {
        try await spreadsheet.values(range: range)
    }
    
    /// Set values in the range
    public func set(_ values: [[String]]) async throws(SheetsError) {
        try await spreadsheet.updateValues(range: range, values: values)
    }
    
    /// Clear the range
    public func clear() async throws(SheetsError) {
        try await spreadsheet.clearValues(range: range)
    }
}
