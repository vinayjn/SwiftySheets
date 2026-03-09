import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol URLSessionProtocol: Sendable {
    func data(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)?
    ) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

/// The main client for interacting with Google Sheets API.
/// Thread-safe actor that manages all API communication.
public actor Client {
    private let transport: SheetsTransport

    /// Access to Google Drive operations (list, create, delete spreadsheets).
    public nonisolated var drive: DriveClient {
        DriveClient(transport: transport)
    }

    /// Initialize with a Google credentials provider.
    public init(credentials: GoogleCredentials) {
        self.transport = SheetsTransport(credentials: credentials, session: URLSession.shared)
    }

    /// Internal init for testing with custom session.
    init(credentials: GoogleCredentials, session: URLSessionProtocol) {
        self.transport = SheetsTransport(credentials: credentials, session: session)
    }

    func makeRequest<T: Decodable & Sendable>(_ request: URLRequest) async throws(SheetsError) -> T {
        let (data, response) = try await sendTransport(request)
        return try ResponseHandler.validateAndDecode(data: data, response: response)
    }

    func makeRequest(_ request: URLRequest) async throws(SheetsError) {
        let (data, response) = try await sendTransport(request)
        try ResponseHandler.validate(data: data, response: response)
    }

    private func sendTransport(_ request: URLRequest) async throws(SheetsError) -> (Data, URLResponse) {
        do {
            return try await transport.send(request)
        } catch {
            throw SheetsError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - Public API

public extension Client {
    func spreadsheet(id: String) async throws(SheetsError) -> Spreadsheet {
        try await Spreadsheet(client: self, id: id)
    }

    func createSpreadsheet(title: String) async throws(SheetsError) -> Spreadsheet {
        let body: [String: Any] = ["properties": ["title": title]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw .invalidRequest
        }

        guard let request = try? Endpoint.create.request(with: bodyData) else {
            throw .invalidRequest
        }
        let responseMetadata: Spreadsheet.Metadata = try await makeRequest(request)

        return Spreadsheet(client: self, metadata: responseMetadata)
    }

    func deleteSpreadsheet(id: String) async throws(SheetsError) {
        try await drive.delete(id: id)
    }

    func listSpreadsheets() async throws(SheetsError) -> [DriveFile] {
        return try await drive.list().spreadsheets().notTrashed().execute()
    }

    func updateValues(
        spreadsheetId: String,
        range: String,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws(SheetsError) -> UpdateValuesResponse {
        let requestBody = UpdateValuesRequest(range: range, values: values)
        guard let bodyData = try? JSONEncoder().encode(requestBody),
              let request = try? Endpoint.updateValues(
                spreadsheetId: spreadsheetId,
                range: range,
                valueInputOption: valueInputOption.rawValue
              ).request(with: bodyData) else {
            throw .invalidRequest
        }

        return try await makeRequest(request)
    }

    func appendValues(
        spreadsheetId: String,
        range: String,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws(SheetsError) -> UpdateValuesResponse {
        let requestBody = UpdateValuesRequest(range: range, values: values)
        guard let bodyData = try? JSONEncoder().encode(requestBody),
              let request = try? Endpoint.appendValues(
                spreadsheetId: spreadsheetId,
                range: range,
                valueInputOption: valueInputOption.rawValue
              ).request(with: bodyData) else {
            throw .invalidRequest
        }

        let response: AppendValuesResponse = try await makeRequest(request)
        return response.updates
    }

    @discardableResult
    func batchUpdate(
        spreadsheetId: String,
        requests: [BatchUpdateRequest.Request]
    ) async throws(SheetsError) -> BatchUpdateResponse {
        let requestBody = BatchUpdateRequest(requests: requests)
        guard let bodyData = try? JSONEncoder().encode(requestBody),
              let request = try? Endpoint.batchUpdate(spreadsheetId: spreadsheetId).request(with: bodyData) else {
            throw .invalidRequest
        }

        return try await makeRequest(request)
    }

    @discardableResult
    func clearValues(spreadsheetId: String, range: String) async throws(SheetsError) -> ClearValuesResponse {
        guard let request = try? Endpoint.clearValues(spreadsheetId: spreadsheetId, range: range).request(with: Data("{}".utf8)) else {
            throw .invalidRequest
        }
        return try await makeRequest(request)
    }

    @discardableResult
    func batchUpdate(
        spreadsheetId: String,
        @BatchUpdateBuilder requests: @Sendable () -> [BatchUpdateRequest.Request]
    ) async throws(SheetsError) -> BatchUpdateResponse {
        try await batchUpdate(spreadsheetId: spreadsheetId, requests: requests())
    }
}
