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
    
    // MARK: - Developer Experience
    
    func cell(_ range: String) async throws -> String? {
        let values = try await self.values(range: range)
        return values.first?.first
    }
    
    func cell(row: Int, column: Int) async throws -> String? {
        // row is 1-based, column is 1-based.
        // Convert to A1.
        // Col 1 -> index 0 -> "A"
        let colStr = SheetRange.indexToColumn(column - 1)
        let range = "\(colStr)\(row)"
        // If sheet name? This assumes active sheet or default?
        // The API `cell(_ range)` uses Range string which can contain sheet name.
        // If row/col is used, we usually imply the first sheet or need a sheet name argument.
        // Let's assume default sheet for now or require sheet name in a separate overload if needed.
        // For DX, simpliest is default.
        return try await cell(range)
    }
    
    // Access with Sheet Name
    func cell(sheet: String, row: Int, column: Int) async throws -> String? {
        let colStr = SheetRange.indexToColumn(column - 1)
        let range = "\(sheet)!\(colStr)\(row)"
        return try await cell(range)
    }

    func resize(sheetId: Int, rows: Int, columns: Int) async throws {
        // Need to find existing properties to preserve index/title?
        // No, UpdateSheetProperties with fields="gridProperties" only updates those fields.
        // But we need the sheetId in the properties object.
        let gridProps = Sheet.GridProperties(rowCount: rows, columnCount: columns)
        let props = Sheet.SheetProperties(
            sheetId: sheetId,
            title: "", // Ignored by fields mask
            index: 0, // Ignored
            gridProperties: gridProps
        )
        let request = BatchUpdateRequest.Request.updateSheetProperties(
            UpdateSheetPropertiesRequest(properties: props, fields: "gridProperties")
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
        
        return GridRange(range: range, sheetId: sheetId)
    }
    
    @discardableResult
    func clearValues(range: String) async throws -> ClearValuesResponse {
        try await client.clearValues(spreadsheetId: id, range: range)
    }
}
