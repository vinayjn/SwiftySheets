import Foundation

public struct Spreadsheet {
    public struct Metadata: Codable {
        public let spreadsheetId: String
        public let properties: Properties
        public let sheets: [Sheet]

        public struct Properties: Codable {
            public let title: String
        }
    }

    private let client: Client
    private let id: String
    public private(set) var metadata: Metadata

    init(client: Client, id: String) async throws {
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
    static func fetchMetadata(id: String, client: Client) async throws -> Metadata {
        let request = try Endpoint.spreadsheet(id: id).request()
        do {
            return try await client.makeRequest(request)
        } catch {
            throw SheetsError.spreadsheetNotFound(message: "Id: \(id)")
        }        
    }
}

public extension Spreadsheet {
    func values(
        range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) async throws -> [[String]] {
        let request = try Endpoint.values(
            spreadsheetId: id,
            range: range.description,
            valueRenderOption: valueRenderOption.rawValue,
            dateTimeRenderOption: dateTimeRenderOption.rawValue
        ).request()
        let response: ValueRange = try await client.makeRequest(request)
        return response.values
    }

    mutating func refreshMetadata() async throws {
        metadata = try await Self.fetchMetadata(id: id, client: client)
    }

    func sheets(afterRefreshingMetadata _: Bool = false) throws -> [Sheet] {
        metadata.sheets
    }

    func sheet(named name: String) throws -> Sheet {
        guard
            let sheet = try sheets().first(where: { $0.properties.title == name })
        else {
            throw SheetsError.sheetNotFound(message: "Name: \(name)")
        }
        return sheet
    }
    
    @discardableResult
    func updateValues(
        range: SheetRange,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws -> UpdateValuesResponse {
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
    ) async throws -> UpdateValuesResponse {
        try await client.appendValues(
            spreadsheetId: id,
            range: range.description,
            values: values,
            valueInputOption: valueInputOption
        )
    }
    
    // MARK: - Batch Update
    
    @discardableResult
    func batchUpdate(requests: [BatchUpdateRequest.Request]) async throws -> BatchUpdateResponse {
        return try await client.batchUpdate(spreadsheetId: id, requests: requests)
    }
    
    @discardableResult
    func batchUpdate(@BatchUpdateBuilder _ builder: @Sendable () -> [BatchUpdateRequest.Request]) async throws -> BatchUpdateResponse {
        try await batchUpdate(requests: builder())
    }
    
    func addSheet(title: String, rowCount: Int = 1000, columnCount: Int = 26) async throws {

        let request = AddSheet(title, gridProperties: Sheet.GridProperties(rowCount: rowCount, columnCount: columnCount))
        try await batchUpdate(requests: [request.request])
    }
    
    // MARK: - Generic Codable Helpers
    
    func values<T: SheetRowDecodable>(
        range: SheetRange,
        type: T.Type,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) async throws -> [T] {
        let rawValues = try await values(
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
        return try rawValues.map { try T(row: $0) }
    }
    
    @discardableResult
    func updateValues<T: SheetRowEncodable>(
        range: SheetRange,
        values: [T],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws -> UpdateValuesResponse {
        let encodedValues = try values.map { try $0.encodeRow() }
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
    ) async throws -> UpdateValuesResponse {
        let encodedValues = try values.map { try $0.encodeRow() }
        return try await appendValues(
            range: range,
            values: encodedValues,
            valueInputOption: valueInputOption
        )
    }
    
    // MARK: - Advanced Operations
    
    func format(range: SheetRange, format: CellFormat) async throws {
        let sheet = try resolveSheet(for: range)
        
        // Use updated DSL dot syntax
        let request = FormatCells(
            sheet: sheet,
            range: range,
            format: format
        )
        
        try await batchUpdate(requests: [request.request])
    }
    
    func sort(range: SheetRange, column: Int, ascending: Bool = true) async throws {
        let sheet = try resolveSheet(for: range)
        
        // Use updated DSL dot syntax
        let request = SortRange(
            sheet: sheet,
            range: range,
            column: column,
            ascending: ascending
        )
        try await batchUpdate(requests: [request.request])
    }
    
    @discardableResult
    func clearValues(range: SheetRange) async throws -> ClearValuesResponse {
        try await client.clearValues(spreadsheetId: id, range: range.description)
    }
    
    // MARK: - Developer Experience
    
    func cell(_ range: SheetRange) async throws -> String? {
        let values = try await self.values(range: range)
        return values.first?.first
    }
    
    func cell(row: Int, column: Int) async throws -> String? {
        let colStr = SheetRange.indexToColumn(column - 1)
        let r = SheetRange.root().from(col: try SheetColumn(colStr), row: try SheetRowIndex(row))
        return try await cell(r)
    }
    
    // Access with Sheet Name
    func cell(sheet: String, row: Int, column: Int) async throws -> String? {
        let colStr = SheetRange.indexToColumn(column - 1)
        let r = SheetRange.root(sheet).from(col: try SheetColumn(colStr), row: try SheetRowIndex(row))
        return try await cell(r)
    }

    func resize(sheetId: Int, rows: Int, columns: Int) async throws {

        let request = ResizeSheet(
            sheet: Sheet(properties: Sheet.SheetProperties(sheetId: sheetId, title: "", index: 0, gridProperties: Sheet.GridProperties(rowCount: 0, columnCount: 0))),
            rows: rows,
            columns: columns
        )
        try await batchUpdate(requests: [request.request])
    }

    private func resolveSheet(for range: SheetRange) throws -> Sheet {
        if let name = range.sheetName {
            return try sheet(named: name)
        } else {
             guard let first = metadata.sheets.first else {
                 throw SheetsError.spreadsheetNotFound(message: "No sheets found")
             }
             return first
        }
    }
}
