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
        range: String,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) async throws -> [[String]] {
        let request = try Endpoint.values(
            spreadsheetId: id,
            range: range,
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
    
    func updateValues(
        range: String,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws -> UpdateValuesResponse {
        try await client.updateValues(
            spreadsheetId: id,
            range: range,
            values: values,
            valueInputOption: valueInputOption
        )
    }
    
    func appendValues(
        range: String,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws -> UpdateValuesResponse {
        try await client.appendValues(
            spreadsheetId: id,
            range: range,
            values: values,
            valueInputOption: valueInputOption
        )
    }
    
    @discardableResult
    func batchUpdate(requests: [BatchUpdateRequest.Request]) async throws -> BatchUpdateResponse {
        return try await client.batchUpdate(spreadsheetId: id, requests: requests)
    }
    
    func addSheet(title: String, rowCount: Int = 1000, columnCount: Int = 26) async throws {
        let properties = Sheet.Draft(
            title: title,
            gridProperties: Sheet.GridProperties(rowCount: rowCount, columnCount: columnCount)
        )
        let request = BatchUpdateRequest.Request.addSheet(AddSheetRequest(properties: properties))
        try await batchUpdate(requests: [request])
    }
    
    func values<T: SheetRowDecodable>(
        range: String,
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
    func batchUpdate(@BatchUpdateBuilder _ builder: @Sendable () -> [BatchUpdateRequest.Request]) async throws -> BatchUpdateResponse {
        try await batchUpdate(requests: builder())
    }
    
    @discardableResult
    func updateValues<T: SheetRowEncodable>(
        range: String,
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
        range: String,
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
    
    func format(range: String, format: CellFormat) async throws {
        let gridRange = try resolveGridRange(from: range)
        
        let cellData = CellData(userEnteredFormat: format)
        let request = BatchUpdateRequest.Request.repeatCell(
            RepeatCellRequest(range: gridRange, cell: cellData, fields: "userEnteredFormat")
        )
        
        try await batchUpdate(requests: [request])
    }
    
    func sort(range: String, column: Int, ascending: Bool = true) async throws {
        let gridRange = try resolveGridRange(from: range)
        let sortSpec = SortSpec(
            dimensionIndex: column,
            sortOrder: ascending ? .ascending : .descending
        )
        let request = BatchUpdateRequest.Request.sortRange(
            SortRangeRequest(range: gridRange, sortSpecs: [sortSpec])
        )
        try await batchUpdate(requests: [request])
    }

    private func resolveGridRange(from range: String) throws -> GridRange {
        let sheetRange = SheetRange(stringLiteral: range)
        
        // 1. Resolve Sheet ID
        let sheetId: Int
        if let name = sheetRange.sheetName {
            sheetId = try sheet(named: name).properties.sheetId
        } else {
             guard let first = metadata.sheets.first else {
                 throw SheetsError.spreadsheetNotFound(message: "No sheets found")
             }
             sheetId = first.properties.sheetId
        }
        
        // 2. Resolve GridRange
        let startRowIndex = sheetRange.startRow.map { $0 - 1 }
        
        var endRowIndex: Int? = sheetRange.endRow
        if endRowIndex == nil, let start = startRowIndex {
            // If start is defined but end is not (e.g. "A1"), it implies a single cell/row, so end = start + 1
            // Unless it's an open range like "A1:". But my parser doesn't support "A1:" explicitly as distinct from A1 usually.
            // "A1" -> startRow=1, endRow=nil. gridRange needs endRowIndex=1 for single row.
            
            // Fix: Only apply this if endColumn is ALSO nil. If endColumn is present (e.g. "A2:C"), it means "A2 to C (unbounded rows)".
            if sheetRange.endColumn == nil {
                endRowIndex = start + 1
            }
        }
        
        let startColumnIndex = sheetRange.startColumn.map { SheetRange.columnToIndex($0) }
        
        var endColumnIndex: Int?
        if let endColStr = sheetRange.endColumn {
            endColumnIndex = SheetRange.columnToIndex(endColStr) + 1
        } else if let start = startColumnIndex {
             // If start col defined ("A1") but end is nil, imply single column.
             endColumnIndex = start + 1
        }
        
        return GridRange(
            sheetId: sheetId,
            startRowIndex: startRowIndex,
            endRowIndex: endRowIndex,
            startColumnIndex: startColumnIndex,
            endColumnIndex: endColumnIndex
        )
    }
    
    @discardableResult
    func clearValues(range: String) async throws -> ClearValuesResponse {
        try await client.clearValues(spreadsheetId: id, range: range)
    }
}
