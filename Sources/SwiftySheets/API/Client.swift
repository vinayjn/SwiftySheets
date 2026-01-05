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
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw SheetsError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw handleErrorResponse(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SheetsError.invalidResponse(status: httpResponse.statusCode)
        }
    }

    func makeRequest(_ request: URLRequest) async throws(SheetsError) {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw SheetsError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SheetsError.invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw handleErrorResponse(data: data, statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields)
        }
    }
    
    private func handleErrorResponse(data: Data, statusCode: Int, headers: [AnyHashable: Any]) -> SheetsError {
        let retryAfter = extractRetryAfter(from: headers)
        
        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                if apiError.error.status == "PERMISSION_DENIED" {
                    return .permissionDenied(message: apiError.error.message)
                } else if apiError.error.message.contains("quota") {
                    return .quotaExceeded(retryAfter: retryAfter)
                }
                return .apiError(apiError)
            }
            return .permissionDenied(message: "Access denied")
        case 404:
            return .spreadsheetNotFound(message: "Resource not found")
        case 429:
            return .rateLimitExceeded(retryAfter: retryAfter)
        default:
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                return .apiError(apiError)
            }
            return .invalidResponse(status: statusCode)
        }
    }
    
    private func extractRetryAfter(from headers: [AnyHashable: Any]) -> TimeInterval? {
        if let retryAfterStr = headers["Retry-After"] as? String {
            return TimeInterval(retryAfterStr)
        }
        return nil
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
        return try await drive.list(query: DriveQuery.spreadsheets.and(.notTrashed).query)
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

private struct EmptyResponse: Decodable {}
