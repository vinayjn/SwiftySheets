import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct DriveClient: Sendable {
    private let transport: SheetsTransport
    private let baseURL = URL(string: "https://www.googleapis.com/drive/v3")!
    
    init(transport: SheetsTransport) {
        self.transport = transport
    }
    
    // MARK: - Read
    
    internal func list(query: String? = nil) async throws(SheetsError) -> [DriveFile] {
        var url = baseURL.appendingPathComponent("files")
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields", value: "files(id, name, mimeType)"),
            URLQueryItem(name: "pageSize", value: "1000")
        ]
        
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        url.append(queryItems: queryItems)
        
        let request = URLRequest(url: url)
        let response: DriveFileList = try await validateAndDecode(sendRequest(request))
        return response.files
    }
    
    /// Create a fluent query builder for listing Drive files.
    /// ```swift
    /// let reports = try await client.drive.list()
    ///     .spreadsheets()
    ///     .notTrashed()
    ///     .nameContains("Report")
    ///     .execute()
    /// ```
    public func list() -> DriveListBuilder {
        DriveListBuilder(driveClient: self)
    }
    
    // MARK: - Write
    
    public enum FileType: Sendable {
        case spreadsheet
        case folder
        
        var mimeType: String {
            switch self {
            case .spreadsheet: return "application/vnd.google-apps.spreadsheet"
            case .folder: return "application/vnd.google-apps.folder"
            }
        }
    }
    
    public func create(name: String, type: FileType = .spreadsheet, parents: [String]? = nil) async throws(SheetsError) -> DriveFile {
        let url = baseURL.appendingPathComponent("files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata = CreateFileRequest(name: name, mimeType: type.mimeType, parents: parents)
        guard let body = try? JSONEncoder().encode(metadata) else {
            throw .invalidRequest
        }
        request.httpBody = body
        
        return try await validateAndDecode(sendRequest(request))
    }
    
    public func delete(id: String) async throws(SheetsError) {
        let url = baseURL.appendingPathComponent("files").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        try await validate(sendRequest(request))
    }
    
    private func sendRequest(_ request: URLRequest) async throws(SheetsError) -> (Data, URLResponse) {
        do {
            return try await transport.send(request)
        } catch {
            throw .networkError(error.localizedDescription)
        }
    }
    
    private func validateAndDecode<T: Decodable>(_ result: (Data, URLResponse)) throws(SheetsError) -> T {
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                throw .apiError(apiError)
            }
            throw .invalidResponse(status: httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .invalidResponse(status: httpResponse.statusCode)
        }
    }
    
    private func validate(_ result: (Data, URLResponse)) throws(SheetsError) {
        let (data, response) = result
        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse(status: 500)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                throw .apiError(apiError)
            }
            throw .invalidResponse(status: httpResponse.statusCode)
        }
    }
}

// Internal request model
struct CreateFileRequest: Encodable, Sendable {
    let name: String
    let mimeType: String
    let parents: [String]?
}
