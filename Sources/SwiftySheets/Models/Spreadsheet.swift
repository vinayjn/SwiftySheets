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

    func sheets() -> [Sheet] {
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
    internal func batchUpdate(requests: [BatchUpdateRequest.Request]) async throws(SheetsError) -> BatchUpdateResponse {
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
            return try rawValues.enumerated().map { index, row in
                do {
                    return try T(row: row)
                } catch {
                    throw SheetsError.decodingError(context: "Failed to decode \(T.self) at row \(index): \(error)")
                }
            }
        } catch let error as SheetsError {
            throw error
        } catch {
            throw .decodingError(context: "Failed to decode \(T.self): \(error)")
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

    internal func format(range: SheetRange, format: CellFormat) async throws(SheetsError) {
        let sheet = try resolveSheet(for: range)
        let request = FormatCells(sheet: sheet, range: range, format: format)
        try await batchUpdate(requests: [request.request])
    }

    /// Create a fluent format builder for the specified range.
    /// ```swift
    /// try await spreadsheet.format(#Range("A1:D1"))
    ///     .backgroundColor(.blue)
    ///     .bold()
    ///     .apply()
    /// ```
    func format(_ range: SheetRange) -> FormatBuilder {
        FormatBuilder(spreadsheet: self, range: range)
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

    func resize(sheetId: Int, rows: Int, columns: Int) async throws(SheetsError) {
        let request = ResizeSheet(
            sheetId: sheetId,
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

    /// Access cells with a validated SheetRange: `spreadsheet[#Range("A1:B10")]`
    /// Or use the new Column DSL: `spreadsheet[Column.A[1]...Column.B[10]]`
    subscript(_ range: SheetRange) -> RangeAccessor {
        RangeAccessor(spreadsheet: self, range: range)
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

    // MARK: - Single Value Helpers

    /// Get the first cell value in the range
    public func stringValue() async throws(SheetsError) -> String? {
        try await spreadsheet.cell(range)
    }

    /// Set a single value (top-left cell of range)
    public func set(_ value: String) async throws(SheetsError) {
        try await spreadsheet.updateValues(range: range, values: [[value]])
    }
}
