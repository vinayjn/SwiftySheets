import Foundation

public struct Spreadsheet {
    public struct Metadata: Decodable {
        public let spreadsheetId: String
        public let properties: Properties
        public let sheets: [Sheet]

        public struct Properties: Decodable {
            public let title: String
        }
    }

    private let client: Client
    private let id: String
    private var metadata: Metadata

    init(client: Client, id: String) async throws {
        self.client = client
        self.id = id
        metadata = try await Self.fetchMetadata(id: id, client: client)
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
}
