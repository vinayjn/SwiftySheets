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
}
