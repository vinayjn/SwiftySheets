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
public final class Client: @unchecked Sendable {
    private let transport: SheetsTransport
    
    /// Access to Google Drive operations (list, create, delete spreadsheets).
    public lazy var drive: DriveClient = DriveClient(transport: transport)
    
    /// Initialize with a Google credentials provider.
    public init(credentials: GoogleCredentials) {
        self.transport = SheetsTransport(credentials: credentials, session: URLSession.shared)
    }
    
    /// Internal init for testing with custom session.
    init(credentials: GoogleCredentials, session: URLSessionProtocol) {
        self.transport = SheetsTransport(credentials: credentials, session: session)
    }

    func makeRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await transport.send(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            try handleErrorResponse(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }

    func makeRequest(_ request: URLRequest) async throws {
        let (data, response) = try await transport.send(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            try handleErrorResponse(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }
    }
    
    private func handleErrorResponse(data: Data, statusCode: Int, headers: [AnyHashable: Any]) throws -> Never {
        let retryAfter = extractRetryAfter(from: headers)
        
        switch statusCode {
        case 401:
            throw SheetsError.authenticationFailed
        case 403:
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                if apiError.error.status == "PERMISSION_DENIED" {
                    throw SheetsError.permissionDenied(message: apiError.error.message)
                } else if apiError.error.message.contains("quota") {
                    throw SheetsError.quotaExceeded(retryAfter: retryAfter)
                }
                throw SheetsError.apiError(apiError)
            }
            throw SheetsError.permissionDenied(message: "Access denied")
        case 404:
            throw SheetsError.spreadsheetNotFound(message: "Resource not found")
        case 429:
            throw SheetsError.rateLimitExceeded(retryAfter: retryAfter)
        default:
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                throw SheetsError.apiError(apiError)
            }
            throw SheetsError.invalidResponse(status: statusCode)
        }
    }
    
    private func extractRetryAfter(from headers: [AnyHashable: Any]) -> TimeInterval? {
        if let retryAfterStr = headers["Retry-After"] as? String {
            return TimeInterval(retryAfterStr)
        }
        return nil
    }
}

public extension Client {
    func spreadsheet(id: String) async throws -> Spreadsheet {
        try await Spreadsheet(client: self, id: id)
    }
    
    func createSpreadsheet(title: String) async throws -> Spreadsheet {
        let body: [String: Any] = ["properties": ["title": title]]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let request = try Endpoint.create.request(with: bodyData)
        let responseMetadata: Spreadsheet.Metadata = try await makeRequest(request)
        
        return Spreadsheet(client: self, metadata: responseMetadata)
    }
    
    func deleteSpreadsheet(id: String) async throws {
        try await drive.delete(id: id)
    }
    
    func listSpreadsheets() async throws -> [DriveFile] {
        return try await drive.list(query: DriveQuery.spreadsheets.and(.notTrashed).query)
    }
    
    func updateValues(
        spreadsheetId: String,
        range: String,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws -> UpdateValuesResponse {
        let requestBody = UpdateValuesRequest(range: range, values: values)
        let bodyData = try JSONEncoder().encode(requestBody)
        let request = try Endpoint.updateValues(
            spreadsheetId: spreadsheetId,
            range: range,
            valueInputOption: valueInputOption.rawValue
        ).request(with: bodyData)
        
        return try await makeRequest(request)
    }
    
    func appendValues(
        spreadsheetId: String,
        range: String,
        values: [[String]],
        valueInputOption: ValueInputOption = .userEntered
    ) async throws -> UpdateValuesResponse {
        let requestBody = UpdateValuesRequest(range: range, values: values)
        let bodyData = try JSONEncoder().encode(requestBody)
        let request = try Endpoint.appendValues(
            spreadsheetId: spreadsheetId,
            range: range,
            valueInputOption: valueInputOption.rawValue
        ).request(with: bodyData)
        
        let response: AppendValuesResponse = try await makeRequest(request)
        return response.updates
    }
    
    @discardableResult
    func batchUpdate(
        spreadsheetId: String,
        requests: [BatchUpdateRequest.Request]
    ) async throws -> BatchUpdateResponse {
        let requestBody = BatchUpdateRequest(requests: requests)
        let bodyData = try JSONEncoder().encode(requestBody)
        let request = try Endpoint.batchUpdate(spreadsheetId: spreadsheetId).request(with: bodyData)
        
        return try await makeRequest(request)
    }
    
    @discardableResult
    func clearValues(spreadsheetId: String, range: String) async throws -> ClearValuesResponse {
        // Empty body for clear request
        let request = try Endpoint.clearValues(spreadsheetId: spreadsheetId, range: range).request(with: Data("{}".utf8))
        return try await makeRequest(request)
    }
    
    @discardableResult
    func batchUpdate(
        spreadsheetId: String,
        @BatchUpdateBuilder requests: @Sendable () -> [BatchUpdateRequest.Request]
    ) async throws -> BatchUpdateResponse {
        try await batchUpdate(spreadsheetId: spreadsheetId, requests: requests())
    }
}

private struct EmptyResponse: Decodable {}
